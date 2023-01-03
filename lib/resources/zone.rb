module Mechahue::Resource
  class Zone < Base
    def lights
      native_hub.find(type: "light") { |group| group[:owned][:rid] == id }
    end

    def grouped_lights
      native_hub.find(type: "grouped_light") { |group| group[:owned][:rid] == id }
    end

    def scenes
      native_hub.find(type: "scene") { |scene| scene[:group][:rid] == id }
    end

    def scene(name)
      scenes.select { |scene| scene.name == name }.first
    end
  end
end