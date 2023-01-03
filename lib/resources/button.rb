module Mechahue::Resource
  class Button < Base
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
end