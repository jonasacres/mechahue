module Mechahue
  class Hub
    def self.named(hostname)
      # take a hostname, return a Hub
      # do registration if that's a thing we still need to do
    end

    def self.default_authfile_path
      File.expand_path("~/hue-auth")
    end

    def self.stored(authfile=nil)
      authfile ||= default_authfile_path
      begin
        JSON.parse(authfile).map do |hub_info|
          Hub.new(hub_info)    
        end
      rescue Exception => exc
        []
      end
    end

    attr_reader :resources, :default_duration, :default_long_press_threshold

    def initialize(info={})
      @hostname = info[:hostname] || info[:ip]
      @id = info[:id]
      @key = info[:application_key] || info[:username]
      @resources = {}
      @default_duration = 0.5
      @default_long_press_threshold = 0.5
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
          lines[0..-2].each do |line|
            next unless m = line.match(/^(\w+): (.*)$/)
            cmd, data = m[1]

            case cmd
            when "data"
              messages = JSON.parse(data, symbolize_names:true)
              messages.each do |msg|
                case msg[:type]
                when :update
                  Mechahue::Update.with_hub_and_info(self, msg)
                end
              end
            end
          end
        end
      end

      request_args = {
        method: :get,
        url: "https://hue-upper.culdesac.kobalabs.net/eventstream/clip/v2",
        verify_ssl: OpenSSL::SSL::VERIFY_NONE,
        headers: {:"hue-application-key" => @key},
        block_response: chunk_handler
        read_timeout: 60*60*24*365.24*100
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

    def stop_event_stream
      @event_stream_start = nil
      self
    end

    def find(params={})
      results = @resources.values
      params.keys.inject(@resources) { |results, key| results.select { |res| res[key] == params[key] } }
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
        @resources[resource[:id]] ||= Resource.with_hub_and_info(self, info)
        @resources[resource[:id]].update(info)
      end
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

    def request_v2(method, endpoint, payload=nil, headers={}, args={})
      resp, result = rest_request(method, File.join("/clip/v2", endpoint), payload, { :"hue-application-key" => @key }.merge(headers), args)

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

    def request_v1(method, endpoint, payload=nil, headers={}, args={})
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

    def rest_request(method, endpoint, payload=nil, headers={}, args={})
      args = {
        rest_args:{},
      }.merge(params)
      params[:rest_args].merge!(args[:rest_args]) if args[:rest_args].is_a?(Hash)

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
        raise RequestFailedException.new(url, method, payload,
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
end
