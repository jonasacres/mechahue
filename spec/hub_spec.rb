require 'securerandom'

NUM_THINGS = 5

def make_id
  SecureRandom.uuid
end

def make_id_v1(type)
  "/#{type}s/#{rand(128)}"
end

def make_basic(type)
  {
    type: type,
    id: make_id,
    id_v1: make_id_v1(type),
  }
end

def make_reference(type)
  {
    rtype: type,
    rid: make_id,
  }
end

def make_button(params={})
  make_basic("button").merge({
    owner: make_reference("device"),
    metadata: { control_id: 0 },
    button: { last_event: "short_release" }
  }).merge(params)
end

def make_device(params={})
  make_basic("device").merge({
    product_data:{
      model_id: "ExampleDevice",
      manufacturer_name: "Acme",
      product_name: "Friends of Coyote Trap",
      product_archetype: "sultan_bulb",
      certified: false,
      software_version: "1.2.3",
    },

    metadata: {
      name: "ExampleDevice",
      archetype: "sultan_bulb",
    },

    services: [
      make_reference("light"),
    ],
  }).merge(params)
end

def make_grouped_light(params={})
  make_basic("grouped_light").merge({
    owner: make_reference("room"),
    on: { on: true },
    dimming: { brightness: 100 },
  }).merge(params)
end

def make_light(params={})
  make_basic("light").merge({
    owner: make_reference("device"),
    metadata: {
      name: "Some Light",
      archetype: "sultan_bulb",
    },
    on: { on: true },
    dimming: { brightness: 80, min_dim_leven: 1 },
    color_temperature: {
      mirek: 153,
      mirek_valid: true,
      mirek_schema: { mirek_minimum: 153, mirek_maximum: 500 },
    },
    color: {
      xy: { x: 0.312, y: 0.328 },
      gamut: { red: { x: 0.6915, y: 0.3083 }, green: { x: 0.1700, y: 0.7000 }, blue: { x: 0.1532, y: 0.0475 } },
      gamut_type: "C",
    },
    mode: "normal",
  }).merge(params)
end

def make_room(params={})
  make_basic("room").merge({
    children: 3.times.map { make_reference("device") },
    services: 3.times.map { make_reference("light") },
    metadata: {
      name: "Example Room",
      archetype: "living_room",
    }
  }).merge(params)
end

def make_scene(params={})
  make_basic("scene").merge({
    actions:[],
    metadata: {
      name: "Example Scene",
    },
    group: make_reference("room"),
    speed: 0,
    auto_dynamic: false,
  }).merge(params)
end

def make_zigbee_connectivity(params={})
  make_basic("zigbee_connectivity").merge({
    owner: make_reference("device"),
    status: "connected",
    mac_address: "00:11:22:33:44:55",
  }).merge(params)
end

def make_zone(params={})
  make_basic("zone").merge({
    children: 3.times.map { make_reference("device") },
    services: 3.times.map { make_reference("light") },
    metadata: {
      name: "Example Zone",
      archetype: "living_room",
    }
  }).merge(params)
end

def make_reference_from_resource(resource)
  {
    rid: resource[:id],
    rtype: resource[:type],
  }
end

def make_resource_tree
  rooms = NUM_THINGS.times.map { |n| make_room }
  zones = NUM_THINGS.times.map { |n| make_zone }

  light_devices   = NUM_THINGS.times.map { |n| make_device }
  button_devices  = NUM_THINGS.times.map { |n| make_device }
  switch_devices  = NUM_THINGS.times.map { |n| make_device }

  light_services  = light_devices.map { |dev| make_light(owner: make_reference_from_resource(dev))  }
  zigbee_services = light_devices.map { |dev| make_zigbee_connectivity(owner: make_reference_from_resource(dev))  }
  button_services = button_devices.map { |dev| make_button(owner: make_reference_from_resource(dev)) }
  switch_services = switch_devices.map { |dev| 4.times.map { |n| make_button(owner: make_reference_from_resource(dev), metadata:{control_id:n}) } }.flatten
  grouped_lights  = NUM_THINGS.times.map { |n| make_grouped_light(owner:make_reference_from_resource(rooms[n])) }
  grouped_lights += NUM_THINGS.times.map { |n| make_grouped_light(owner:make_reference_from_resource(zones[n])) }

  scenes = rooms.map { |room| make_scene(group: make_reference_from_resource(room)) }

  NUM_THINGS.times.each do |n|
    light_devices[n][:services] = [ light_services[n], zigbee_services[n] ]
    button_devices[n][:services] = [ button_services[n] ]
    switch_devices[n][:services] = [ switch_services[4*n ... 4*(n+1)].flatten ]
    
    rooms[n][:devices] = [ make_reference_from_resource(light_devices[n]) ]
    rooms[n][:services] = [ light_devices[n][:services], grouped_lights[n] ].flatten

    zones[n][:devices] = [ make_reference_from_resource(light_devices[n]) ]
    zones[n][:services] = [ light_devices[n][:services], grouped_lights[5+n] ].flatten
  end

  resources_with_services = light_devices + button_devices + switch_devices + rooms + zones
  services = resources_with_services.map { |res| res[:services] }.flatten.uniq

  resources_with_services + services + scenes
end

def make_v2_result(list)
  { errors:[], data:list }
end

describe Mechahue::Hub do
  let(:hub) { Mechahue::Hub.new(hostname:"hue.example.com", id:"testcase", application_key:"testkey") }
  let(:resources) { make_resource_tree }
  let(:buttons) { resources.select { |resource| resource[:type] == "button" } }
  let(:devices) { resources.select { |resource| resource[:type] == "device" } }
  let(:grouped_lights) { resources.select { |resource| resource[:type] == "grouped_light" } }
  let(:lights)  { resources.select { |resource| resource[:type] == "light" } }
  let(:rooms)   { resources.select { |resource| resource[:type] == "room" } }
  let(:zones)   { resources.select { |resource| resource[:type] == "zone" } }
  let(:scenes)  { resources.select { |resource| resource[:type] == "scene" } }

  def stub_v2_get_resources
    stub_request(:get, "https://#{hub.hostname}/clip/v2/resource").to_return(body:make_v2_result(resources).to_json)
  end

  describe "::named" do
    context "with a previously registered hostname" do
      it "returns a Mechahue::Hub object"
    end

    context "with a previously unknown hostname" do
      it "returns nil" do
        expect(Mechahue::Hub.named("sdfjosifjsidofj")).to be_nil
      end
    end
  end

  describe "::default_authfile_path" do
    it "returns a string path" do
      expect(Mechahue::Hub.default_authfile_path).to be_a(String)
    end
  end

  describe "::stored" do
    context "given an explicit path" do
      it "returns a hash of hubs from the indicated path" do
        test_info = { "records" => { "testhost.example" => { "username" => "uzer000", "id" => "testhost-id", "ip" => "testhost.example" } } }
        tempfile = Tempfile.new("hub_spec")
        tempfile.write(test_info.to_json)
        tempfile.flush

        stored = Mechahue::Hub.stored(tempfile.path)
        expect(stored["testhost.example"].hostname).to eq "testhost.example"
        expect(stored["testhost.example"].key).to eq "uzer000"
        expect(stored["testhost.example"].id).to eq "testhost-id"
      end
    end

    context "given no path" do
      it "returns a hash of hubs from default_authfile_path"
      # alter default_authfile_path to a test file, same test as read from indicated path
    end

    it "raises an exception if the path does not exist" do
      expect(Mechahue::Hub.stored("/flip/flop/glip/glorp/doesntexist")).to eq({})
    end

    it "raises an exception if the file is not parseable" do
      badfile = Tempfile.new("hub_spec")
      badfile.write("not json")
      badfile.flush

      expect { Mechahue::Hub.stored(badfile.path) }.to raise_error(JSON::ParserError)
    end
  end

  describe "#activate" do
    let(:updates) { [
          {
            type: "update",
            data: [
              make_reference_from_resource(rooms.first)
            ],
            creationtime: "", # TODO: FILL THIS IN WITH ACTUAL HUE API TIMESTAMP
          }
        ] }

    before(:each) do
      stub_request(:get, "https://#{hub.hostname}/eventstream/clip/v2").to_return do |request|
        { body: ": hi\n\ndata: #{updates.to_json}\n\n" }
      end

      stub_v2_get_resources
    end

    after(:each) do
      hub.deactivate
    end

    def wait_for_event_stream
      sleep 0.1 # TODO: lol, make this work for real
    end

    it "opens a connection to the event stream" do
      hub.activate

      wait_for_event_stream
      expect(a_request(:get, "https://#{hub.hostname}/eventstream/clip/v2")).to have_been_made
    end

    it "causes incoming events to be delivered to watchers" do
      notified = false
      hub.watch do |update|
        expect(updates.first[:data].first[:id]).to eq update.id
        notified = true
      end

      hub.activate
      wait_for_event_stream

      expect(notified).to eq true
    end

    it "makes periodic synchronous queries in the background to maintain state"
    
    it "makes an immediate blocking synchronous query to establish state" do
      hub.activate
      wait_for_event_stream
      expect(a_request(:get, "https://#{hub.hostname}/clip/v2/resource")).to have_been_made.at_least_once
    end

    it "begins processing scheduled tasks" do
      invoked = false
      hub.task(:foo, 0.01) { invoked = true }
      hub.activate

      sleep 0.1 # TODO: also lol, need a better option to waiting arbitrary times
      expect(invoked).to be true
    end

    it "restarts the event stream when disconnected"
  end

  describe "#deactivate" do
    it "closes the event stream connection"
    it "stops making synchronous queries in the background"
    it "stops processing scheduled tasks"
  end

  describe "#watch" do
    context "when given a type list" do
      it "causes Hub to invoke the block when a new event of any specified type arrives in the event stream" do
        saw_event = nil
        my_event = {"gee" => "whiz"}
        hub.watch([:somekey1, :somekey2, :somekey3]) { |event| saw_event = event }
        hub.send(:notify_event, :somekey2, my_event)

        expect(saw_event).to be my_event
      end

      it "does not causes Hub to invoke the block when a new event not of any specified type arrives in the event stream" do
        saw_event = nil
        my_event = {"gee" => "whiz"}
        hub.watch([:somekey1, :somekey2, :somekey3]) { |event| saw_event = event }
        hub.send(:notify_event, :someotherkey, my_event)

        expect(saw_event).to be_nil
      end
    end

    context "when type list omitted" do
      it "causes Hub to invoke the block when a new event arrives in the event stream" do
        saw_event = nil
        my_event = {"gee" => "whiz"}
        hub.watch { |event| saw_event = event }
        hub.send(:notify_event, :somekey, my_event)

        expect(saw_event).to be my_event
      end
    end

    it "supports multiple watch callbacks" do
      saw_event_a, saw_event_b = nil
      my_event = {"gee" => "whiz"}
      hub.watch { |event| saw_event_a = event }
      hub.watch { |event| saw_event_b = event }
      hub.send(:notify_event, :somekey, my_event)

      expect(saw_event_a).to be my_event
      expect(saw_event_b).to be my_event
    end
  end

  describe "#find" do
    before(:each) do
      stub_v2_get_resources
      hub.refresh
    end

    it "returns a list of resources including all toplevel key-value pairs matching the supplied parameters" do
      results = hub.find(type: "room")
      expect(results.count).to eq NUM_THINGS
      resources.select { |res| res[:type] == "room" }.each do |room|
        expect(results.select { |res| res[:id] == room[:id] }.count).to eq 1
      end
    end

    it "does not include any resources whose top-level key-value paris differ from supplied parameters" do
      results = hub.find(type: "room")
      results.each do |res|
        expect(res[:type]).to eq "room"
      end
    end

    context "given a block" do
      it "invokes the block for each parameter-matching resource" do
        seen_ids = []
        hub.find(type: "room") { |res| seen_ids << res[:id] }
        expect(seen_ids.count).to eq NUM_THINGS
      end

      it "does not invoke the block for any non-parameter-matching resource" do
        hub.find(type: "room") { |res| expect(res[:type]).to eq "room" }
      end

      it "returns a list consisting of all the resources for which the block returned truthy" do
        expected_ids = rooms[0..2].map { |room| room[:id] }.sort
        seen_ids = []

        results = hub.find(type: "room") do |res|
          if expected_ids.include?(res[:id]) then
            seen_ids << res[:id]
            "this looks truthy"
          else
            false
          end
        end

        expect(seen_ids.sort).to eq expected_ids
      end
    end
  end

  context do
    before(:each) { stub_v2_get_resources }

    context do
      before(:each) { hub.refresh }

      [
        ["light", Mechahue::Resource::Light],
        ["scene", Mechahue::Resource::Scene],
        ["device", Mechahue::Resource::Device],
        ["room", Mechahue::Resource::Room],
        ["zone", Mechahue::Resource::Zone],
        ["grouped_light", Mechahue::Resource::GroupedLight],
        ["button", Mechahue::Resource::Button],
      ].each do |type, klass|
        it "lists all resources of type 'light'" do
          expect(hub.lights.count).to eq lights.count
          hub.send(:"#{type}s").each do |thing|
            my_things = self.send(:"#{type}s")
            has_thing = my_things.select { |my_thing| my_thing[:id] == thing[:id] }.count > 0
            expect(has_thing).to be true
          end
        end

        it "does not list any resources whose type is not 'thing'" do
          hub.send(:"#{type}s").each { |thing| expect(thing[:type]).to eq type }
        end

        it "returns Resource::Light objects" do
          hub.send(:"#{type}s").each { |thing| expect(thing).to be_a klass }
        end
      end

      describe "#lights" do
        it "lists all resources of type 'light'" do
          expect(hub.lights.count).to eq lights.count
          hub.lights.each do |light|
            has_light = lights.select { |my_light| my_light[:id] == light[:id] }.count > 0
            expect(has_light).to be true
          end
        end

        it "does not list any resources whose type is not 'light'" do
          hub.lights.each { |light| expect(light[:type]).to eq "light" }
        end

        it "returns Resource::Light objects" do
          hub.lights.each { |light| expect(light).to be_a Mechahue::Resource::Light }
        end
      end
    end
    
    describe "#rules_v1" do
      it "makes a V1 API request for rule objects"
      it "returns a Hash of API V1 rule objects"
    end
    
    describe "#refresh" do
      it "makes a V2 API request for /resource" do
        url = "https://#{hub.hostname}/clip/v2/resource"
        stub = stub_request(:get, url).to_return(body: {errors:[], data:[]}.to_json)
        hub.refresh
        expect(stub).to have_been_requested
      end

      it "updates the info of all existing resources"
      it "blocks until the update is complete"
      
      it "instantiates new resource objects for resources that were not previously known" do
        expect(hub.resources).to be_empty
        hub.refresh
        expect(hub.resources).not_to be_empty
        expect(hub.resources.count).to eq resources.count
      end

      it "does not instantiate new resource objects for previously existing resources" do
        hub.refresh
        existing = hub.resources.clone
        hub.refresh
        expect(hub.resources).to eq existing
      end
    end

    describe "#resolve_reference" do
      before(:each) do
        stub_v2_get_resources
        hub.refresh
      end

      context "when given an invalid V2 API reference" do
        it "raises an exception" do
          expect { hub.resolve_reference({}) }.to raise_error(RuntimeError)
          expect { hub.resolve_reference([]) }.to raise_error(RuntimeError)
          expect { hub.resolve_reference(nil) }.to raise_error(RuntimeError)
          expect { hub.resolve_reference(7) }.to raise_error(RuntimeError)
          expect { hub.resolve_reference("string") }.to raise_error(RuntimeError)

          expect { hub.resolve_reference({id: "only-id"}) }.to raise_error(RuntimeError)
          expect { hub.resolve_reference({type: "only-type"}) }.to raise_error(RuntimeError)
          expect { hub.resolve_reference({rid: "only-rid"}) }.to raise_error(RuntimeError)
          expect { hub.resolve_reference({rtype: "only-rtype"}) }.to raise_error(RuntimeError)
        end
      end

      context "when given a previously-known reference" do
        it "returns the existing resource object" do
          res_info = lights.first

          res_object = hub.resources[res_info[:id]]
          expect(res_object).to be_a(Mechahue::Resource::Base)

          reference = make_reference_from_resource(res_info)
          result = hub.resolve_reference(reference)

          expect(result).to be res_object
        end
      end

      context "when given a previously-unknown reference" do
        it "makes a synchronous V2 API request for that object" do
          info = make_light
          stub = stub_request(:get, "https://#{hub.hostname}/clip/v2/resource/#{info[:type]}/#{info[:id]}").to_return { { body: make_v2_result([info]).to_json } }
          hub.resolve_reference(make_reference_from_resource(info))
          expect(stub).to have_been_requested
        end

        it "returns the new resource object" do
          info = make_light
          stub = stub_request(:get, "https://#{hub.hostname}/clip/v2/resource/#{info[:type]}/#{info[:id]}").to_return { { body: make_v2_result([info]).to_json } }
          result = hub.resolve_reference(make_reference_from_resource(info))
          expect(result).to be_a(Mechahue::Resource::Light)

          info.each do |key, value|
            expect(result[key]).to eq value
          end
        end

        it "registers the new resource object in the resources list" do
          info = make_light
          stub = stub_request(:get, "https://#{hub.hostname}/clip/v2/resource/#{info[:type]}/#{info[:id]}").to_return { { body: make_v2_result([info]).to_json } }
          hub.resolve_reference(make_reference_from_resource(info))
          expect(hub.resources[info[:id]]).not_to be_nil
        end
      end
    end
  end

  describe "get_v2" do
    it "makes a V2 API GET request to the specified endpoint" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:get, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.get_v2("foo")
      expect(a_request(:get, url).with(headers:{"hue-application-key" => hub.key})).to have_been_made
    end

    it "returns a Hash representing the data section of the parsed result" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:get, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.get_v2("foo")
      expect(result).to eq([pish:"posh"])
    end
  end

  describe "post_v2" do
    it "makes a V2 API POST request to the specified endpoint with the specified payload" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      payload = {foo:"bar"}
      stub = stub_request(:post, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.post_v2("foo", payload)
      expect(a_request(:post, url).with(headers:{"hue-application-key" => hub.key}, body: payload.to_json)).to have_been_made
    end

    it "returns a Hash representing the data section of the parsed result" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:post, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.post_v2("foo", "foo")
      expect(result).to eq([pish:"posh"])
    end
  end

  describe "put_v2" do
    it "makes a V2 API POST request to the specified endpoint with the specified payload" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      payload = {foo:"bar"}
      stub = stub_request(:put, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.put_v2("foo", payload)
      expect(a_request(:put, url).with(headers:{"hue-application-key" => hub.key}, body: payload.to_json)).to have_been_made
    end

    it "returns a Hash representing the data section of the parsed result" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:put, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.put_v2("foo", "foo")
      expect(result).to eq([pish:"posh"])
    end
  end

  describe "delete_v2" do
    it "makes a V2 API GET request to the specified endpoint" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:delete, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.delete_v2("foo")
      expect(a_request(:delete, url).with(headers:{"hue-application-key" => hub.key})).to have_been_made
    end

    it "returns a Hash representing the data section of the parsed result" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:delete, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.delete_v2("foo")
      expect(result).to eq([pish:"posh"])
    end
  end

  describe "request_v2" do
    it "issues HTTP requests to the appropriate URL" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:get, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.request_v2(:get, "foo")
      expect(a_request(:get, url)).to have_been_made
    end

    it "returns the data section of the parsed result" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:get, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.request_v2(:get, "foo")
      expect(result).to eq([pish:"posh"])
    end

    it "includes the appropriate hue-application-key header" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:get, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.request_v2(:get, "foo")
      expect(a_request(:get, url).with(headers:{:"hue-application-key" => hub.key})).to have_been_made
    end

    it "includes the requested payload and headers" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:post, url).to_return(body: {errors:[], data:[{pish:"posh"}]}.to_json)
      result = hub.request_v2(:post, "foo", "hi there", {foo:"bar"})
      expect(a_request(:post, url).with(headers:{foo:"bar"}, body:"hi there")).to have_been_made
    end

    context "when the :ignore_errors parameter is not set" do
      it "raises RequestFailedException when API errors occur" do
        url = "https://#{hub.hostname}/clip/v2/foo"
        stub = stub_request(:get, url).to_return(body: {errors:[description:"oh no"], data:{pish:"posh"}}.to_json)
        expect { hub.request_v2(:get, "foo") }.to raise_error(Mechahue::RequestFailedException)
      end

      it "raises RequestFailedException when HTTP errors occur" do
        url = "https://#{hub.hostname}/clip/v2/foo"
        stub = stub_request(:get, url).to_return(status:400, body: {errors:[], data:[{pish:"posh"}]}.to_json)
        expect { hub.request_v2(:get, "foo") }.to raise_error(Mechahue::RequestFailedException)
      end
    end

    context "when the :ignore_errors parameter is set to :comm" do
      it "raises RequestFailedException when HTTP errors occur" do
        url = "https://#{hub.hostname}/clip/v2/foo"
        stub = stub_request(:get, url).to_return(status:400, body: {errors:[], data:[{pish:"posh"}]}.to_json)
        expect { hub.request_v2(:get, "foo", nil, {}, ignore_errors: :comm) }.to raise_error(Mechahue::RequestFailedException)
      end

      it "raises RequestFailedException when an API error occurs that does not include the phrase 'communication issues'" do
        url = "https://#{hub.hostname}/clip/v2/foo"
        stub = stub_request(:get, url).to_return(body: {errors:[description:"warp core breach"], data:{pish:"posh"}}.to_json)
        expect { hub.request_v2(:get, "foo", nil, {}, ignore_errors: :comm) }.to raise_error(Mechahue::RequestFailedException)
      end

      it "does not raise an exception when an API error occurs that includes the phrase 'communication issues'" do
        url = "https://#{hub.hostname}/clip/v2/foo"
        stub = stub_request(:get, url).to_return(body: {errors:[description:"got some communication issues, dang"], data:[{pish:"posh"}]}.to_json)
        result = hub.request_v2(:get, "foo", nil, {}, ignore_errors: :comm)
        expect(result).to eq([pish:"posh"])
      end
    end

    it "raises RequestFailedException when the API result is not valid JSON" do
      url = "https://#{hub.hostname}/clip/v2/foo"
      stub = stub_request(:get, url).to_return(body: "i am not valid json")
      expect { hub.request_v2(:get, "foo") }.to raise_error(Mechahue::RequestFailedException)
    end

    it "raises RequestFailedException when the API result is not in the expected format" do
      url = "https://#{hub.hostname}/clip/v2/foo"

      bad_responses = [ {razzle:"dazzle"}, nil, 7, Math::PI, "a string",
                        {errors:{}, data:{}}, {errors:[]}, {errors:{}, data:[]}, {errors:{}, data:"foo"} ]
      bad_responses.each do |bad_resp|
        stub = stub_request(:get, url).to_return(body: bad_resp.to_json)
        expect { hub.request_v2(:get, "foo") }.to raise_error(Mechahue::RequestFailedException)
      end
    end
  end

  describe "get_v1" do
    it "makes a V1 API GET request to the specified endpoint" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      stub = stub_request(:get, url).to_return(body: {blip:"blorp"}.to_json)
      result = hub.get_v1("foo")
      expect(a_request(:get, url)).to have_been_made
    end

    it "returns an object representing the parsed result" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      stub = stub_request(:get, url).to_return(body: {blip:"blorp"}.to_json)
      result = hub.get_v1("foo")
      expect(result).to eq({blip:"blorp"})
    end
  end

  describe "post_v1" do
    it "makes a V1 API POST request to the specified endpoint with the specified payload encoded as JSON" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      body = {payload:"i am a body"}
      stub = stub_request(:post, url).with(body: body.to_json).to_return(body: {blip:"blorp"}.to_json)
      result = hub.post_v1("foo", body)
      expect(stub).to have_been_requested
    end

    it "returns an object representing the parsed result" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      body = {payload:"i am a body"}
      stub = stub_request(:post, url).with(body: body.to_json).to_return(body: {blip:"blorp"}.to_json)
      result = hub.post_v1("foo", body)
      expect(result).to eq({blip:"blorp"})
    end
  end

  describe "put_v1" do
    it "makes a V1 API PUT request to the specified endpoint with the specified payload encoded as JSON" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      body = {payload:"i am a body"}
      stub = stub_request(:put, url).with(body: body.to_json).to_return(body: {blip:"blorp"}.to_json)
      result = hub.put_v1("foo", body)
      expect(stub).to have_been_requested
    end

    it "returns an object representing the parsed result" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      body = {payload:"i am a body"}
      stub = stub_request(:put, url).with(body: body.to_json).to_return(body: {blip:"blorp"}.to_json)
      result = hub.put_v1("foo", body)
      expect(result).to eq({blip:"blorp"})
    end
  end

  describe "delete_v1" do
    it "makes a V1 API DELETE request to the specified endpoint" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      stub = stub_request(:delete, url).to_return(body: {blip:"blorp"}.to_json)
      result = hub.delete_v1("foo")
      expect(a_request(:delete, url)).to have_been_made
    end

    it "returns an object representing the parsed result" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      stub = stub_request(:delete, url).to_return(body: {blip:"blorp"}.to_json)
      result = hub.delete_v1("foo")
      expect(result).to eq({blip:"blorp"})
    end
  end

  describe "request_v1" do
    it "issues HTTP requests to the appropriate URL" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      stub = stub_request(:get, url).to_return(body: {blip:"blorp"}.to_json)
      result = hub.request_v1(:get, "foo")
      expect(a_request(:get, url)).to have_been_made
    end

    it "includes the requested payload and headers" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      stub = stub_request(:post, url).to_return(body: {blip:"blorp"}.to_json)
      result = hub.request_v1(:post, "foo", "hi there", {testkey:"testvalue"})
      expect(a_request(:post, url).with(body:"hi there", headers:{testkey:"testvalue"})).to have_been_made
    end

    it "raises RequestFailedException when the API result is not valid JSON" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      stub = stub_request(:get, url).to_return(body: "i am not json")
      expect { hub.request_v1(:get, "foo") }.to raise_error(Mechahue::RequestFailedException)
    end

    it "returns the parsed object" do
      url = "https://#{hub.hostname}/api/#{hub.key}/foo"
      stub = stub_request(:post, url).to_return(body: {blip:"blorp"}.to_json)
      result = hub.request_v1(:post, "foo", "hi there", {testkey:"testvalue"})
      expect(result).to eq(blip:"blorp")
    end
  end

  describe "#rest_request" do
    it "issues a request with the specified method, endpoint, payload and headers" do
      stub = stub_request(:put, "https://#{hub.hostname}/foo").to_return(body: {blip:"blorp"}.to_json)
      resp, result = hub.rest_request(:put, "/foo", "hi there", {"X-Dog" => "Bark"})
      expect(a_request(:put, "https://#{hub.hostname}/foo").with({headers:{"X-Dog" => "Bark"}, body:"hi there"})).to have_been_requested
    end

    it "returns an array bearing the response object, and parsed JSON" do
      stub_request(:put, "https://#{hub.hostname}/foo")
        .to_return(body: {blip:"blorp"}.to_json)
      resp, result = hub.rest_request(:put, "/foo", "hi there", {"X-Dog" => "Bark"})
      expect(resp).to be_a(RestClient::Response)
      expect(result).to eq({blip:"blorp"})
    end

    it "raises RequestFailedException when the result is not parseable as JSON" do
      stub_request(:put, "https://#{hub.hostname}/foo")
        .to_return(body: "i'm not json")
      expect { hub.rest_request(:put, "/foo", "hi there", {"X-Dog" => "Bark"}) }.to raise_error(Mechahue::RequestFailedException)
    end

    context "when HTTP 429 encountered" do
      it "retries the request :max_retries times before raising an error" do
        stub = stub_request(:get, "https://#{hub.hostname}/foo").to_return(status: 429)
        expect { hub.rest_request(:get, "/foo", nil, {}, max_retries:3, retry_delay:0) }.to raise_error(Mechahue::RequestFailedException)
        expect(stub).to have_been_requested.times(3)
      end

      it "pauses between API requests" do
        timestamps = []
        stub = stub_request(:get, "https://#{hub.hostname}/foo").to_return do |req|
          timestamps << Time.now
          {status: 429}
        end

        count = 3
        delay = 0.005

        expect { hub.rest_request(:get, "/foo", nil, {}, max_retries:count, retry_delay:delay) }.to raise_error(Mechahue::RequestFailedException)
        expect(stub).to have_been_requested.times(count)
        expect(timestamps.count).to eq(count)
        
        (count-1).times.each do |i|
          expect(timestamps[i+1] - timestamps[i]).to be >= delay
        end
      end

      it "stops retrying after the API generates any other error" do
        stub = stub_request(:get, "https://#{hub.hostname}/foo").to_return(status: 429).to_return(status:200, body:"not json")
        expect { hub.rest_request(:get, "/foo", nil, {}, max_retries:3, retry_delay:0) }.to raise_error(Mechahue::RequestFailedException)
        expect(stub).to have_been_requested.times(2)
      end

      it "stops retrying after the API generates a successful result" do
        stub = stub_request(:get, "https://#{hub.hostname}/foo").to_return(status: 429)
                                                                .to_return(status:200, body:"{}")
        hub.rest_request(:get, "/foo", nil, {}, max_retries:3, retry_delay:0)
        expect(stub).to have_been_requested.times(2)
      end
    end
  end

  describe "#task" do
    it "schedules the task to be invoked when run_tasks executes" do
      var = 0
      hub.task(:test, 0) { var = 1 }
      expect(var).to eq(0)
      hub.send(:run_tasks)
      expect(var).to eq(1)
    end

    it "overwrites existing tasks of the same ID" do
      var1, var2 = [false, false]
      hub.task(:test, 0) { var1 = true }
      hub.task(:test, 0) { var2 = true }
      expect(var1).to eq false
      expect(var2).to eq false
      hub.send(:run_tasks)
      expect(var1).to eq false
      expect(var2).to eq true
    end

    context "when Hub is active" do
      it "causes the block to be invoked at the requested interval"
    end

    context "when Hub is not active" do
      it "does not cause the block to be invoked while the Hub remains inactive"
      it "causes the block to be invoked at the requested interval when the Hub is made active"
    end
  end

  describe "#end_task" do
    it "causes the task with the specified ID to stop being invoked when run_tasks executes" do
      var = 0
      hub.task(:test, 0) { var = 1 }
      hub.end_task(:test)
      hub.send(:run_tasks)
      expect(var).to eq(0)
    end

    it "does not raise an exception when the specified task_id does not correspond to a previously registered task" do
      hub.end_task(:test)
    end
  end
end
