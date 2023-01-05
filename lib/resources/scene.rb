module Mechahue::Resource
  class Scene < Base
    def recall(params={})
      recall_args = {
        action: "active",
        duration: (1000*native_hub.default_duration).round(0).to_i
      }

      recall_args[:duration] = (1000*params[:duration]).round(0).to_i if params[:duration]
      recall_args[:dimming] = { brightness: params[:brightness] } if params[:brightness]

      put(recall:recall_args)
    end
  end
end
