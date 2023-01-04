module Mechahue::Resource
  class GroupedLight < Light
    def self.type
      "grouped_light"
    end

    def mechacolor
      Mechahue::Color.from_light(info)
    end

    def set_color(new_color, params={})
      light_command(new_color.to_light, params)
    end

    def on?
      info[:on][:on]
    end

    def set_on(new_on, params={})
      light_command({on:{on: new_on}}, params)
    end

    def set_brightness(new_brightness, params={})
      light_command({dimming:{brightness:new_brightness.round(0).to_i}}, params)
    end

    def light_command(state, params={})
      args = {
        duration: native_hub.default_duration,
        ignore_errors: :comm, # grouped lights throw a bunch of bogus error messages as of 2023-01-04
      }.merge(params)

      dynamics = {}
      dynamics[:duration] = (1000*args[:duration]).to_i if args[:duration]
      dynamics[:speed] = args[:speed] if args[:speed]

      message = {}
      message[:dynamics] = dynamics unless dynamics.empty?
      message = message.gentle_merge(state)

      req_params = { ignore_errors: args[:ignore_errors] }

      native_hub.put_v2(endpoint, message, req_params)
      self
    end

    def lights
      self.owner_resource.children.select { |ref|    ref[:rtype] == "device" }
                                  .map    { |ref|    native_hub.resolve_reference(ref) }
                                  .map    { |device| device.services.select { |service| service[:rtype] == "light" } }
                                  .flatten
                                  .map    { |ref|    native_hub.resolve_reference(ref) }
    end

    def to_s
      str  = type
      str += " " + id
      str += " " + (owner_resource.name || "untitled")
      str += " #{on? ? "on" : "off"}"
    end
  end
end
