module Mechahue::Update
  class FOHSwitchUpdate < Base
    attr_reader :duration

    def self.supported_resource
      Mechahue::Resource::FOHSwitch
    end

    def upper_left?
      0 == resource[:metadata][:control_id]
    end

    def lower_left?
      1 == resource[:metadata][:control_id]
    end

    def lower_right?
      2 == resource[:metadata][:control_id]
    end

    def upper_right?
      3 == resource[:metadata][:control_id]
    end

    def up?
      button? && resource_info[:button][:last_event] == "short_release"
    end

    def down?
      button? && resource_info[:button][:last_event] == "initial_press"
    end

    def button?
      resource_info[:button] && resource_info[:button].has_key?(:last_event)
    end
  end
end
