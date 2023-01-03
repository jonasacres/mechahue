module Mechahue::Resource
  class Light < Base
    def mechacolor
      Mechahue::Color.from_light(info)
    end

    def set_color(new_color, additional={})
      native_hub.put_v2(endpoint, {color: new_color.to_device_xy}.merge(params))
      self
    end

    def on?
      info[:on][:on]
    end

    def set_on(new_on, additional={})
      native_hub.put_v2(endpoint, {on: {on: new_on}}.merge(additional))
      self
    end
  end
end
