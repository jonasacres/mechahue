module Mechahue::Resource
  class Scene < Base
    def recall(params={})
      recall_args = { action: "active", duration: native_hub.default_duration }
      recall_args[:duration] = params[:duration] if params[:duration]
      recall_args[:dimming] = { brightness: params[:brightness] } if params[:brightness]

      put(recall:recall_args)
    end
  end
end
