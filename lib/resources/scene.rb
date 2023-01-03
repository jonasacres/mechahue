module Mechahue::Resource
  class Scene < Base
    def recall(params={})
      recall_args = { action: "active", duration: native_hub.default_duration }
      put(recall:recall_args)
    end
  end
end
