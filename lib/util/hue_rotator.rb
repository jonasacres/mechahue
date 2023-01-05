module Mechahue
  class HueRotator
    attr_reader :update_frequency, :period, :lights, :time_started

    def initialize(lights, period)
      @lights = lights
      @period = period
      @update_frequency = if period < 5*60.0
        1.000
      elsif period <= 10*60.0
        2.000
      elsif period <= 60*60.0
        5.00
      else
        10.00
      end

      @lights.map { |light| light.native_hub }.uniq.each { |hub| hub.refresh }
      @base_colors = {}
      @lights.each { |light| @base_colors[light] = light.mechacolor }
      @time_started = Time.now
    end

    def start
      @uuid = uuid = SecureRandom.uuid

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
      elapsed = Time.now - @time_started
      2*Math::PI/@period * elapsed
    end

    def update
      puts angle
      puts @lights

      @lights.each do |light|
        begin
          new_color = @base_colors[light].rotate_hue(angle)
          light.set_color(new_color, duration: @update_frequency + 1.0)
        rescue Exception => exc
          puts "Encountered error rotating light #{light}\n#{exc.class} #{exc}\n#{exc.backtrace.join("\n")}"
        end
      end

      puts "updated"
    end
  end
end
