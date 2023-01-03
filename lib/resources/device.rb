module Mechahue::Resource
  class Device < Base
    def self.construct(native_hub, info={})
      if info[:product_data] && info[:product_data][:model_id] == "FOHSWITCH" then
        return FOHSwitch.new(native_hub, info)
      end

      super
    end
  end
end
