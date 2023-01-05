module Mechahue::Resource
  class Light < Base
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

    def set_effect(effect, params={})
      light_command({effects:{effect: effect}}, params)
    end

    def light_command(state, params={})
      args = {
        duration: native_hub.default_duration
      }.merge(params)

      dynamics = {}
      dynamics[:duration] = (1000*args[:duration]).to_i if args[:duration]
      dynamics[:speed] = args[:speed] if args[:speed]

      message = {}
      message[:dynamics] = dynamics unless dynamics.empty?
      message = message.gentle_merge(state)
      native_hub.put_v2(endpoint, message)
      self
    end

    def to_s
      str  = id
      str += " " + type
      str += " " + mechacolor.to_hex + " " + mechacolor.color_text_bg(" "*3)
      str += " " + name
      str += " #{on? ? "on" : "off"}"
    end
  end
end
