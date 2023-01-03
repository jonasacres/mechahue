module Mechahue::Update
  class FOHSwitchUpdate < Base
    attr_reader :duration

    def initialize(resource, info)
      super

      @on_resolve = []
      
      if button_up?
        resource.last_update.mark_release(self)
        @duration = resource.last_update.duration
      end
    end

    def self.supported_resource
      Mechahue::Resource::FOHSwitch
    end

    def upper_left?
      resource[:metadata][:control_id] == 0
    end

    def lower_left?
      resource[:metadata][:control_id] == 1
    end

    def lower_right?
      resource[:metadata][:control_id] == 2
    end

    def upper_right?
      resource[:metadata][:control_id] == 3
    end

    def resolve!
      return true if resolved?
      mutex = Mutex.new
      condvar = ConditionVariable.new

      # block until resolved, and check VERY frequently for release
      Thread.new do
        until resolved? do
          resource.refresh
          sleep 0.050
        end

        mutex.synchronize {
          condvar.signal
        }
      end

      mutex.synchronize {
        condvar.wait(mutex)
      }

      true
    end

    def resolved?
      @resolved || check_resolved
    end

    def on_resolve(&block)
      if resolved? then
        block.call(@duration)
      else
        @on_resolve << block
      end
    end

    def button_up?
      @info[:button][:last_update] == "short_release"
    end

    def button_down?
      @info[:button][:last_update] == "initial_press"
    end

    def long_press?
      @duration > resource.native_hub.default_long_press_threshold
    end

    def mark_release(press_update, release_update)
      @duration = if press_update.nil? || release_update.nil? then
        resource.native_hub.default_long_press_threshold
      else
        release_update.timestamp - press_update.timestamp
      end

      @resolved = true
      @on_resolved.each { |block| block.call(duration) }
    end

    def check_resolved
      return true if @resolved

      if button_up? then
        mark_release(resource.last_update, self)
      end

      return false if resource.last_update.sequence <= sequence
      
      if resource.last_update.button_up? then
        mark_release(resource.last_update)
        return @resolved = true
      end

      false
    end
  end
end
