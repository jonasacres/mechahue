module Mechahue::Resource
  class Room < Base
    def devices
      child_resources.select { |child| child.is_a?(Device) }
    end

    def lights
      devices.map    { |device|  device.service_resources }
             .flatten
             .select { |service| service.is_a?(Light) }
    end

    def grouped_lights
      native_hub.find(type: "grouped_light") { |group| group[:owner][:rid] == id }
    end

    def scenes
      native_hub.find(type: "scene") { |scene| scene[:group][:rid] == id }
    end

    def scene(name)
      scenes.select { |scene| scene.name == name }.first
    end
  end
end