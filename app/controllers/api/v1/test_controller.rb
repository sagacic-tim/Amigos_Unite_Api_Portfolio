# app/controllers/api/v1/test_controller.rb
module Api
  module V1
    class TestController < ApplicationController
      # public health check, no auth
      skip_before_action :authenticate_amigo!

      def index
        render json: { message: 'API is working' }, status: :ok
      end
    end
  end
end
