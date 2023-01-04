module Mechahue::Resource
  class Button < Base
    def update(new_update)
      old_state = info[:button][:last_event] rescue nil
      result = super

      return result unless new_update.resource_info[:button] && new_update.resource_info[:button].has_key?(:last_event) && new_update.resource_info[:button][:last_event] != old_state
      new_state = new_update.resource_info[:button][:last_event]

      case new_state
      when "short_release", "long_release"
        @hold_duration = @press_start ? Time.now - @press_start : 0.0
        @is_pressed = false
      when "initial_press", "long_press", "repeat"
        @press_start = Time.now unless @is_pressed
        @is_pressed = true
      end

      result
    end

    def control_id
      @info[:metadata][:control_id]
    end

    def stale?
      down? && Time.now - last_updated_at > 0.100
    end

    def down?
      @is_pressed
    end

    def up?
      !down?
    end

    def hold_duration
      down? ? Time.now - @press_start : (@hold_duration || 0.0)
    end

    def long_press?
      hold_duration >= native_hub.default_long_press_threshold
    end

    def grouped_lights(control_id=nil)
      native_hub.rules_v1.each do |rule_id, rule|
        next unless rule[:conditions].select { |cc| cc[:address] == "#{owner_resource.id_v1}/state/buttonevent" }.count > 0
        next unless rule[:conditions].select { |cc| cc[:operator] == "eq" }.count > 0
        # next unless control_id.nil? || rule[:conditions].select { |cc| cc[:value] == 0x14 | control_id }

        grouped_lights = rule[:actions].map { |act| act[:address].match(/^(\/groups\/(\d+))\//) }
                                     .compact
                                     .map { |addr_match| addr_match[1] }
                                     .map { |group_id_v1| native_hub.grouped_lights.select { |group| group.id_v1 == group_id_v1 }.first }
                                     .map { |native_group| native_hub.grouped_lights.select { |group| group.id == native_group.id }.first }
        return grouped_lights
      end

      []
    end

    def to_s
      str = super
      str += " " + (down? ? "down" : "up")
      str += " " + hold_duration.round(3).to_s if hold_duration
      str
    end
  end
end