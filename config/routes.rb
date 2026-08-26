# config/routes.rb
#
# The full route map is omitted from this portfolio snapshot — this is a
# representative excerpt showing the shape of the API (devise-jwt auth
# mapping, nested resources, a couple of custom member/collection actions)
# rather than the complete, exhaustive surface.

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      devise_for :amigos,
        class_name: "Amigo",
        controllers: {
          sessions:      "api/v1/auth/sessions",
          registrations: "api/v1/auth/registrations",
          passwords:     "api/v1/auth/passwords",
          confirmations: "api/v1/confirmations"
        },
        defaults: { format: :json }

      resources :amigos, only: %i[index show create update destroy]

      resources :events do
        member do
          patch :transfer_lead
        end
        collection do
          get :my_events
        end
      end

      resources :event_locations, only: %i[index show create update destroy] do
        member do
          post :store_location_image
        end
      end

      resources :event_amigo_connectors,     only: %i[index create update destroy]
      resources :event_location_connectors,  only: %i[index create update destroy]

      resource :location_suggestions, only: :create
      resources :places, only: :index

      get "test", to: "test#index"
    end
  end
end
