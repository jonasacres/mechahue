module Mechahue
  class HueRotator
    attr_reader :update_frequency, :period, :lights, :time_started

    def initialize(lights, period)
      @lights = lights
      @period = period
      @update_frequency = if period < 60.0
        0.100
      elsif period <=  5*60.0
        2.000
      elsif period <= 60*60.0
        10.00
      else
        30.00
      end
    end

    def start
      @lights.map { |light| light.native_hub }.uniq.each { |hub| hub.refresh }
      @base_colors = {}
      @lights.each { |light| @base_colors[light] = light.mechacolor }
      @uuid = uuid = SecureRandom.uuid
      @time_started = Time.now

      Thread.new do
        while uuid == @uuid do
          sleep @update_frequency
          update
        end
      end

      self
    end

    def stop
      @uuid = nil
      @time_started = nil
    end

    def revert
      stop
      @lights.each { |light| light.set_color(@base_colors[light]) }
    end

    def angle
      @time_started ||= Time.now
      elapsed = Time.now - @time_started
      2*Math::PI/@period * elapsed
    end

    def update
      @lights.each do |light|
        begin
          new_color = @base_colors[light].rotate_hue(angle)
          light.set_color(new_color, duration: @update_frequency + 1.0)
        rescue Exception => exc
          puts "Encountered error rotating light #{light}\n#{exc.class} #{exc}\n#{exc.backtrace.join("\n")}"
        end
      end
    end
  end
end
