module Mechahue::Resource
  def self.resources
    return @resources if @resources

    @resources = {}
    ObjectSpace.each_object(Class).select { |klass| klass < Base }.each { |klass| @resources[klass.type] = klass }
    @resources
  end

  def self.with_hub_and_info(native_hub, info={})
    klass = self.resources[info[:type]] || Base
    klass.construct(native_hub, info)
  end

  class Base
    attr_reader :id, :id_v1, :info, :type, :native_hub, :sequence, :last_update, :last_updated_at

    def self.construct(native_hub, info={})
      self.new(native_hub, info)
    end

    def self.type
      self.name.to_s.split("::").last.downcase
    end

    def initialize(native_hub, info={})
      @native_hub = native_hub
      @info = info
      @watches = []
      @sequence = 0
    end

    def id
      @info[:id]
    end

    def type
      @info[:type]
    end

    def name
      @info[:metadata][:name] rescue nil
    end

    def id_v1
      @info[:id_v1]
    end

    def info_v1
      id_v1 ? native_hub.get_v1(id_v1) : nil
    end

    def refresh
      update_with_info(@native_hub.get_v2(endpoint).first)
      self
    end

    def endpoint
      "/resource/#{type}/#{id}"
    end

    def owner_resource
      return nil unless info[:owner]
      @owner ||= native_hub.resolve_reference(info[:owner])
    end

    def child_resources
      return nil unless info[:children]
      @children ||= info[:children].map { |ref| native_hub.resolve_reference(ref) }
    end

    def service_resources
      return nil unless info[:services]
      @services ||= info[:services].map { |ref| native_hub.resolve_reference(ref) }
    end

    def update(new_update)
      return if @info == new_update.resource_info

      @info = @info.gentle_merge(new_update.resource_info)
      yield if block_given?

      @watches.each do |watch|
        watch[:block].call(new_update)
      end

      @last_update = new_update
      @last_updated_at = new_update.creation_time

      self
    end

    def update_with_info(info)
      update_info = {
        data: [{type: self.class.type, id: self.id}.merge(info)],
        id: SecureRandom.uuid,
        type: "update",
        creationtime: Time.now.to_s,
      }

      Mechahue::Update.batch_instance(self, [], update_info, update_info[:data].first)
    end

    def roll_sequence
      @sequence += 1
    end

    def watch(key=nil, &block)
      @watches.delete_if { |watch| watch[:key] == key } unless key.nil?
      @watches << {key:key, block:block}
      self
    end

    def method_missing(method, *args, &block)
      return super unless args.empty? && @info.has_key?(method)
      @info[method]
    end

    def [](key)
      return info[key]
    end

    def get
      native_hub.get_v2(endpoint)
    end

    def put(payload={})
      native_hub.put_v2(endpoint, payload)
    end

    def delete
      native_hub.delete_v2(endpoint)
    end

    def stale?
      false
    end

    def to_s
      str = "#{id} #{type}"
      str += " '#{name}'" if name
      str
    end

    def inspect
      to_s
    end
  end
end
