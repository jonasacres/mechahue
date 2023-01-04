module Mechahue::Resource
  class FOHSwitch < Device
    def find_control(control_id)
      self.services.each do |service|
        next unless service[:rtype] == "button"
        button = native_hub.resolve_reference(service)
        return button if button.control_id == control_id
      end

      nil
    end

    def upper_left
      @upper_left ||= find_control(0)
    end

    def lower_left
      @lower_left ||= find_control(1)
    end

    def lower_right
      @lower_right ||= find_control(2)
    end

    def upper_right
      @upper_right ||= find_control(3)
    end
  end
end
