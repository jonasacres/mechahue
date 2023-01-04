module Mechahue
  class Hub
    def self.named(hostname)
      # TODO: try to register if we don't have this hub yet. block on wait for link button, raise exception on all other errors.
      stored[hostname]
    end

    def self.default_authfile_path
      File.expand_path("~/hue-auth")
    end

    def self.stored(authfile=nil)
      return @stored_hubs if @stored_hubs
      authfile ||= default_authfile_path
      return {} unless File.exists?(authfile)


      begin
        hubs = JSON.parse(IO.read(authfile), symbolize_names:true)[:records].values.map do |hub_info|
          Hub.new(hub_info)
        end

        @stored_hubs = {}
        hubs.each do |hub|
          @stored_hubs[hub.hostname] = hub
        end
        @stored_hubs
      rescue JSON::ParserError => exc
        STDERR.puts "Can't read authfile: unparseable JSON, #{exc}"
        {}
      rescue Exception => exc
        STDERR.puts "Error instantiating hubs: #{exc.class} #{exc}\n#{exc.backtrace.join("\n")}" if File.exists?(authfile)
        {}
      end
    end

    attr_reader :hostname, :id, :key, :resources, :default_duration, :default_long_press_threshold, :last_refresh
    attr_accessor :monitor_interval

    def initialize(info={})
      @hostname = info[:hostname] || info[:ip]
      @id = info[:id]
      @key = info[:application_key] || info[:username]
      @resources = {}
      @default_duration = 0.5
      @default_long_press_threshold = 0.5
      @monitor_interval = 60.0
      @event_watchers = []
    end

    def activate
      start_event_stream
      refresh
      start_monitor
    end

    def deactivate
      stop_event_stream
      stop_monitor
    end

    def start_monitor
      ts = Time.now
      @monitoring = ts
      Thread.new do
        while @monitoring == ts do
          begin
            stale_list = @resources.values.select { |res| res.stale? }
            if Time.now - @last_refresh > @monitor_interval || stale_list.count > 2 then
              refresh
            else
              stale_list.each { |resource| resource.refresh }
            end
            
            sleep 0.010
          rescue Exception => exc
            puts "Hub #{id} monitor thread caught exception: #{exc.class} #{exc}\n#{exc.backtrace.join("\n")}"
          end
        end
      end
    end

    def stop_monitor
      @monitoring = nil
    end

    def start_event_stream
      start_time = Time.now
      @event_stream_start = start_time

      chunk_handler = proc do |response|
        next unless @event_stream_start == start_time

        pending = ""
        response.read_body do |chunk|
          pending += chunk
          lines = pending.split("\n")
          
          if pending.end_with?("\n") then
            pending = ""
          else
            pending = lines.last
            lines = lines[0..-2]
          end


          lines.each do |line|
            next unless line.start_with?("data: ")
            data = line["data: ".length .. -1]

            messages = JSON.parse(data, symbolize_names:true) rescue []
            messages.each do |msg|
              begin
                case msg[:type]
                when "update"
                  updates = Mechahue::Update.with_hub_and_batch(self, msg)
                  updates.each { |update| notify_event(:update, update) }
                end
              rescue Exception => exc
                puts "Exception #{exc.class} #{exc}\n#{exc.backtrace.join("\n")}"
              end
            end
          end
        end
      end

      request_args = {
        method: :get,
        url: "https://#{hostname}/eventstream/clip/v2",
        verify_ssl: OpenSSL::SSL::VERIFY_NONE,
        headers: {:"hue-application-key" => @key, :"Accept" => "text/event-stream"},
        block_response: chunk_handler,
        read_timeout: 60*60*24*365.24*100,
      }

      Thread.new do
        last_attempt = nil
        
        while @event_stream_start == start_time do
          if last_attempt && Time.now - last_attempt < 5.0 then
            sleep 5.0 - (Time.now - last_attempt)
          end

          last_attempt = Time.now
          RestClient::Request::execute(request_args) rescue nil
        end
      end

      self
    end

    def notify_event(type, event)
      @event_watchers.select! { |watcher| watcher.notify(type, event) }
    end

    def watch(types=nil, &block)
      @event_watchers << EventWatcher.new(types, &block)
      self
    end

    def stop_event_stream
      @event_stream_start = nil
      self
    end

    def find(params={})
      results = params.keys.inject(@resources.values) { |results, key| results.select { |res| res[key] == params[key] } }
      results = results.select { |resource| yield(resource) } if block_given?
      results
    end

    def lights
      find(type: "light")
    end

    def scenes
      find(type: "scene")
    end

    def devices
      find(type: "device")
    end

    def rooms
      find(type: "room")
    end

    def zones
      find(type: "zone")
    end

    def grouped_lights
      find(type: "grouped_light")
    end

    def devices
      find(type: "device")
    end

    def bridges
      find(type: "bridge")
    end

    def buttons
      find(type: "bridge")
    end

    def bridge_homes
      find(type: "bridge_home")
    end

    def rules_v1
      get_v1("/rules")
    end

    def refresh
      get_v2("/resource").each do |info|
        @resources[info[:id]] ||= Resource.with_hub_and_info(self, info)
        @resources[info[:id]].update_with_info(info)
      end

      @last_refresh = Time.now
    end

    def resolve_reference(info={})
      id, type = if info[:id] && info[:type] then
        [info[:id], info[:type]]
      elsif info[:rid] && info[:rtype]
        [info[:rid], info[:rtype]]
      else
        raise "Unresolvable reference: #{info.to_json}, expected id, type or rid, rtype fields"
      end

      return @resources[id] if @resources[id]
      @resources[id] = Resource.with_hub_and_info(id: id, type: type)
      @resources[id].refresh
      @resources[id]
    end

    def get_v2(endpoint)
      request_v2(:get, endpoint)
    end

    def post_v2(endpoint, payload)
      request_v2(:post, endpoint, payload.to_json)
    end

    def put_v2(endpoint, payload)
      request_v2(:put, endpoint, payload.to_json)
    end

    def delete_v2(endpoint)
      request_v2(:delete, endpoint)
    end

    def request_v2(method, endpoint, payload=nil, headers={}, params={})
      resp, result = rest_request(method, File.join("/clip/v2", endpoint), payload, { :"hue-application-key" => @key }.merge(headers), params)

      unless result[:errors].empty? then
        raise RequestFailedException.new(url, method, payload, resp, result, "Server response listed errors: #{result[:errors].to_json}")
      end

      result[:data]
    end

    def get_v1(endpoint)
      request_v1(:get, endpoint)
    end

    def post_v1(endpoint, payload)
      request_v1(:post, endpoint, payload.to_json)
    end

    def put_v1(endpoint, payload)
      request_v1(:put, endpoint, payload.to_json)
    end

    def delete_v1(endpoint, payload)
      request_v1(:delete, endpoint)
    end

    def request_v1(method, endpoint, payload=nil, headers={}, params={})
      args = {
        squish_single:true,
      }.merge(params)

      resp, result = rest_request(method, File.join("/api/#{@key}", endpoint), payload, headers, args)
      retval = if result.is_a?(Array) then
        result.each do |item|
          unless item.is_a?(Hash) then
            raise RequestFailedException.new(url, method, payload, resp, result,
              "Expected second-level JSON responses to be objects")
          end

          if item.has_key?(:error) then
            raise RequestFailedException.new(url, method, payload, resp, result,
              "JSON response contained error: #{item[:error][:description]}")
          end

          unless item.has_key?(:success) then
            raise RequestFailedException.new(url, method, payload, resp, result,
              "JSON response did not contain successful response")
          end
        end
        
        reduced = result.map do |item|
          item[:success]
        end

        reduced = reduced.first if reduced.length == 1 && args[:squish_single]
        reduced
      else
        result
      end

      return retval
    end

    def rest_request(method, endpoint, payload=nil, headers={}, params={})
      args = {
        rest_args:{},
      }.merge(params)
      args[:rest_args].merge!(params[:rest_args]) if params[:rest_args].is_a?(Hash)

      url = File.join("https://#{hostname}", endpoint)

      begin
        request_args = {
          method: method,
          url: url,
          payload: payload,
          verify_ssl: OpenSSL::SSL::VERIFY_NONE,
          headers: headers,
        }.merge(args[:rest_args])

        request_args.delete(:payload) if payload.nil?

        resp = RestClient::Request.execute(request_args)
      rescue RestClient::RequestFailed => exc
        raise RequestFailedException.new(url, method, payload, nil, nil,
          "Server returned #{exc.class}")
      end

            unless (resp.code/100).to_i == 2 then
        raise RequestFailedException.new(url, method, payload, resp, nil,
          "Server returned HTTP #{resp.code}")
      end

      begin
        result = JSON.parse(resp.body, symbolize_names:true)
      rescue JSON::ParserError
        raise RequestFailedException.new(url, method, payload, resp, nil,
          "Unable to parse response as JSON")
      end

      return [resp, result]
    end
  end

  class RequestFailedException < StandardError
    attr_reader :endpoint, :method, :payload, :resp, :parsed, :description

    def initialize(endpoint, method, payload, resp, parsed, description)
      @endpoint = endpoint
      @method = method
      @payload = payload
      @resp = resp
      @parsed = parsed
      @description = description
    end

    def to_s
      "Request failed: #{method.to_s.upcase} #{endpoint} #{description}"
    end
  end

  class EventWatcher
    attr_reader :block

    def initialize(types, &block)
      @types = types ? [*types] : nil
      @block = block
    end

    def notify(type, event)
      block.call(event) unless @cancelled || !wants?(type)
      !@cancelled
    end

    def wants?(type)
      @types.nil? || types.include?(type)
    end

    def cancelled?
      @cancelled
    end

    def cancel
      @cancelled = true
    end

    def to_s
      "hub #{hostname}"
    end
  end
end
