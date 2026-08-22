# app/controllers/api/v1/auth/csrf_controller.rb
module Api
  module V1
    module Auth
      class CsrfController < ApplicationController
        skip_before_action :authenticate_amigo!, raise: false

        def show
          token = form_authenticity_token

          cookies["CSRF-TOKEN"] = {
            value:     token,
            path:      "/",                           # important: available to all routes
            same_site: (request.ssl? ? :none : :lax), # none requires secure in browsers
            secure:    request.ssl?,                  # do not force secure on http specs
            http_only: false
          }

          response.set_header("X-CSRF-Token", token)
          head :no_content
        end
      end
    end
  end
end
