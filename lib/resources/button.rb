module Mechahue::Resource
  class Button < Base
    def update(new_update)
      old_state = info[:button][:last_event] rescue nil
      result = super

      return result unless new_update.resource_info[:button] && new_update.resource_info[:button].has_key?(:last_event) && new_update.resource_info[:button][:last_event] != old_state
      new_state = new_update.resource_info[:button][:last_event]

      case new_state
      when "short_release"
        @is_pressed = false
        @hold_duration = @press_start ? Time.now - @press_start : 0.0
      when "initial_press"
        @is_pressed = true
        @press_start = Time.now
      end

      puts self

      result
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
      down? ? Time.now - @press_start : @hold_duration
    end

    def long_press?
      hold_duration >= native_hub.default_long_press_threshold
    end

    def grouped_lights(control_id=nil)
      native_hub.rules_v1.each do |rule|
        next unless rule.conditions[n][:address] == "/sensors/#{owner.v1_id}/buttonevent"
        next unless rule.conditions[n][:operator] == "eq"
        next unless control_id.nil? || rule.conditions[n][:value] == 0x14 | control_id


        grouped_lights = rule.actions.map { |act| act[:address].match(/^(\/groups\/(\d+))\//) }
                                     .compact
                                     .map { |addr_match| addr_match[1] }
                                     .map { |group_id_v1| switch.native_hub.grouped_lights.select { |group| group.id_v1 == group_id_v1 }.first }
                                     .map { |native_group| switch.hub.grouped_lights.select { |group| group.id == native_group.id }.first }
      end
    end

    def to_s
      str = super
      str += " " + (down? ? "down" : "up")
      str += " " + hold_duration.round(3).to_s if hold_duration
      str
    end
  end
end