describe Mechahue::Hub do
  describe "::named" do
    context "with a previously registered hostname" do
      it "returns a Mechahue::Hub object" do
        # TODO: make this more generic and not dependent on my local setup!
        expect(Mechahue::Hub.named("hue.kobalabs.net")).to be_a(Mechahue::Hub)
      end

      it "does not make network requests"
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

        doubler = class_double("Mechahue::Hub")
        doubler.

        stored = Mechahue::Hub.stored(tempfile.path)
        expect(stored["testhost.example"].hostname).to eq "testhost.example"
        expect(stored["testhost.example"].key).to eq "uzer000"
        expect(stored["testhost.example"].id).to eq "testhost-id"
      end
    end

    context "given no path" do
      it "returns a hash of hubs from default_authfile_path"
      # do
      #   test_info = { "records" => { "testhost.example2" => { "username" => "uzer002", "id" => "testhost-id2", "ip" => "testhost.example2" } } }
      #   tempfile = Tempfile.new("hub_spec")
      #   tempfile.write(test_info.to_json)
      #   tempfile.flush

      #   somehow need to override Hub::default_authfile_path

      #   stored = Mechahue::Hub.stored
      #   expect(stored["testhost.example2"].hostname).to eq "testhost.example2"
      #   expect(stored["testhost.example2"].key).to eq "uzer002"
      #   expect(stored["testhost.example2"].id).to eq "testhost-id2"
      # end
      # # alter default_authfile_path to a test file, same test as read from indicated path
    end

    it "raises an exception if the path does not exist" do
      expect(Mechahue::Hub.stored("/flip/flop/glip/glorp/doesntexist")).to eq({})
    end

    it "raises an exception if the file is not parseable" do
      badfile = Tempfile.new("hub_spec")
      badfile.write("not json")
      badfile.flush

      expect { Mechahue::Hub.stored(badfile.path) }.to raise_error
    end
  end

  describe "#activate" do
    it "opens a connection to the event stream"
    it "makes periodic synchronous queries in the background to maintain state"
    it "makes an immediate blocking synchronous query to establish state"
    it "begins processing scheduled tasks"
  end

  describe "#deactivate" do
    it "closes the event stream connection"
    it "stops making synchronous queries in the background"
    it "stops processing scheduled tasks"
  end

  describe "#watch" do
    it "causes Hub to invoke the block when a new event arrives in the event stream"
    it "supports multiple watch callbacks"
  end

  describe "#find" do
    it "returns a list of resources including all toplevel key-value pairs matching the supplied parameters"
    it "does not include any resources whose top-level key-value paris differ from supplied parameters"

    context "given a block" do
      it "invokes the block for each parameter-matching resource"
      it "does not invoke the block for any non-parameter-matching resource"
      it "returns a list consisting of all the resources for which the block returned truthy"
      it "returns a list containing no resources for which the block returned falsy"
    end
  end

  describe "#lights" do
    it "lists all resources of type 'light'"
    it "does not list any resources whose type is not 'light'"
    it "returns Resource::Light objects"
  end

  describe "#scenes" do
    it "lists all resources of type 'scene'"
    it "does not list any resources whose type is not 'scene'"
    it "returns Resource::Scene objects"
  end

  describe "#devices" do
    it "lists all resources of type 'device'"
    it "does not list any resources whose type is not 'device'"
    it "returns Resource::Device objects"
  end

  describe "#rooms" do
    it "lists all resources of type 'room'"
    it "does not list any resources whose type is not 'room'"
    it "returns Resource::Room objects"
  end
  
  describe "#zones" do
    it "lists all resources of type 'zone'"
    it "does not list any resources whose type is not 'zone'"
    it "returns Resource::Zone objects"
  end
  
  describe "#grouped_lights" do
    it "lists all resources of type 'grouped_light'"
    it "does not list any resources whose type is not 'grouped_light'"
    it "returns Resource::GroupedLight objects"
  end
  
  describe "#bridges" do
    it "lists all resources of type 'bridge'"
    it "does not list any resources whose type is not 'bridge'"
  end
  
  describe "#buttons" do
    it "lists all resources of type 'button'"
    it "does not list any resources whose type is not 'button'"
    it "returns Resource::Button objects"
  end
  
  describe "#bridge_homes" do
    it "lists all resources of type 'bridge_home'"
    it "does not list any resources whose type is not 'bridge_home'"
  end
  
  describe "#rules_v1" do
    it "makes a V1 API request for rule objects"
    it "returns a Hash of API V1 rule objects"
  end
  
  describe "#refresh" do
    it "makes a V2 API request for /resource"
    it "updates the info of all existing resources"
    it "blocks until the update is complete"
    it "instantiates new resource objects for resources that were not previously known"
    it "does not instantiate new resource objects for previously existing resources"
  end

  describe "#resolve_reference" do
    context "when given an invalid V2 API reference" do
      it "raises an exception"
    end

    context "when given a previously-known reference" do
      it "returns the existing resource object"
      it "does not make an API request"
    end

    context "when given a previously-unknown reference" do
      it "makes a synchronous V2 API request for that object"
      it "returns the new resource object"
    end
  end

  describe "get_v2" do
    it "makes a V2 API GET request to the specified endpoint"
    it "returns a Hash representing the data section of the parsed result"
  end

  describe "post_v2" do
    it "makes a V2 API POST request to the specified endpoint with the specified payload"
    it "returns a Hash representing the data section of the parsed result"
  end

  describe "put_v2" do
    it "makes a V2 API PUT request to the specified endpoint with the specified payload"
    it "returns a Hash representing the data section of the parsed result"
  end

  describe "delete_v2" do
    it "makes a V2 API POST request to the specified endpoint"
    it "returns a Hash representing the data section of the parsed result"
  end

  describe "request_v2" do
    it "issues HTTP requests to the appropriate URL"
    it "returns the data section of the parsed result"
    it "includes the appropriate hue-application-key header"

    context "when the :ignore_errors parameter is not set" do
      it "raises an exception when API errors occur"
      it "raises an exception when HTTP errors occur"
    end

    context "when the :ignore_errors parameter is set to :comm" do
      it "raises an exception when API errors occur"
      it "raises an exception when HTTP errors occur"
    end

    it "raises an exception when the API result is not valid JSON"
    it "raises an exception when the API result is not in the expected format"
    it "raises an exception when the API result does not contain a data section"
  end

  describe "get_v1" do
    it "makes a V1 API GET request to the specified endpoint"
    it "returns a Hash representing the data section of the parsed result"
  end

  describe "post_v1" do
    it "makes a V1 API POST request to the specified endpoint with the specified payload"
    it "returns a Hash representing the data section of the parsed result"
  end

  describe "put_v1" do
    it "makes a V1 API PUT request to the specified endpoint with the specified payload"
    it "returns a Hash representing the data section of the parsed result"
  end

  describe "delete_v1" do
    it "makes a V1 API POST request to the specified endpoint"
    it "returns a Hash representing the data section of the parsed result"
  end

  describe "request_v1" do
    it "issues HTTP requests to the appropriate URL"

    it "raises an exception when the API result is not valid JSON"
    it "raises an exception when the API result is not in the expected format"
    it "returns the parsed object"
  end

  describe "#rest_request" do
    it "issues a request with the specified method, endpoint, payload and headers"
    it "returns an array bearing the response object, and parsed JSON"
    it "raises an exception when the result is not parseable as JSON"

    context "when HTTP 429 encountered" do
      it "retries the request a finite number of times"
      it "pauses between API requests"
      it "raises an exception if the API does not accept the request within the finite number of retries"
      it "stops retrying after the API generates any other error"
      it "stops retrying after the API generates a successful result"
    end
  end

  describe "#task" do
    it "overwrites existing tasks of the same ID"

    context "when Hub is active" do
      it "causes the block to be invoked at the requested interval"
    end

    context "when Hub is not active" do
      it "does not cause the block to be invoked while the Hub remains inactive"
      it "causes the block to be invoked at the requested interval when the Hub is made active"
    end
  end

  describe "#end_task" do
    it "causes the task with the specified ID to stop being invoked"
    it "does not raise an exception when the specified task_id does not correspond to a previously registered task"
  end
end
