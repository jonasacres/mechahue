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
    attr_reader :id, :id_v1, :info, :type, :native_hub, :sequence, :last_update

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

    def refresh
      @info.merge!(@native_hub.get(endpoint).first)
      self
    end

    def endpoint
      "/resource/#{type}/#{id}"
    end

    def owner_resource
      return nil unless info[:owner]
      @owner ||= native_hub.resolve_reference(info[:owner])
    end

    def received_update(update)
      self.update(update.info)
      @last_update = update
    end

    def update(new_info)
      return if new_info == info

      @info.merge!(new_info) # TODO: find a better merge, this isn't great with nested hashes

      @watches.each do |watch|
        watch[:block].call(diff)
      end

      self
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

    def to_s
      str = "#{type} #{id}"
      str += " '#{name}'" if name
      str
    end

    def inspect
      to_s
    end
  end
end
