module Mechahue::Update
  def self.updates
    ObjectSpace.each_object(Class).select { |klass| klass < Base }
  end

  def self.with_hub_and_info(hub, info)
    resource = hub.resolve_reference(info)
    self.with_resource_and_info(resource, info)
  end

  def self.with_resource_and_info(resource, info)
    klass = self.updates.select { |update| resource < update.supported_resource }.min
    klass.construct(resource, info)
  end

  def self.construct(resource, info)
    self.new(resource, info)
  end

  class Base
    attr_reader :resource, :diff, :info, :old_state, :creation_time, :received_time, :sequence

    def initialize(resource, info)
      @resource = resource
      @sequence = @resource.roll_sequence
      @diff = HashDiff.diff(resource.info, new_info)
      @info = JSON.parse(info.to_json, symbolize_names:true)
      @old_state = JSON.parse(@resource.info.to_json, symbolize_names:true)  
      @creation_time = Time.parse(info[:creationtime]) rescue nil
      @received_time = Time.now

      @resource.received_update(self)
    end
  end
end
