module Mechahue::Resource
  class ZigbeeConnectivity < Base
    def self.type
      "zigbee_connectivity"
    end

    def to_s
      super + " " + mac_address + " " + status
    end
  end
end