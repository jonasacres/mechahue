module Mechahue::Update
  def self.updates
    @updates ||= ObjectSpace.each_object(Class).select { |klass| klass <= Base }
  end

  def self.with_hub_and_batch(hub, batch_info)
    batch = []
    batch_info[:data].map do |resource_info|
      resource = hub.resolve_reference(resource_info)
      self.batch_instance(resource, batch, batch_info, resource_info)
    end
  end

  def self.batch_instance(resource, batch, batch_info, resource_info)
    klass = self.identify_class(resource, batch_info)
    batch << klass.construct(resource, batch, batch_info, resource_info)
    batch.last
  end

  def self.identify_class(resource, batch_info)
    case resource
    when Mechahue::Resource::Button
      case resource.owner_resource
      when Mechahue::Resource::Device
        case resource.owner_resource[:product_data][:model_id]
        when "FOHSWITCH"
          FOHSwitchUpdate
        else
          Base
        end
      else
        Base
      end
    else
      Base
    end
  end

  class Base
    def self.supported_resource
      Mechahue::Resource::Base
    end

    def self.construct(resource, batch, batch_info, resource_info)
      self.new(resource, batch, batch_info, resource_info)
    end

    attr_reader :resource, :info, :old_state, :creation_time, :received_time, :sequence, :resource_info

    def initialize(resource, batch, batch_info, resource_info)
      @resource = resource
      @resource_info = resource_info
      @batch = batch
      @info = batch_info

      @sequence = @resource.roll_sequence
      @old_state = JSON.parse(@resource.info.to_json, symbolize_names:true)  
      @creation_time = Time.parse(info[:creationtime]) rescue nil
      @received_time = Time.now

      @resource.update(self)
    end

    def id
      info[:id]
    end

    def to_s
      "update #{id}: #{@resource}"
    end
  end
end

