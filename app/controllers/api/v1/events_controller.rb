# app/controllers/api/v1/events_controller.rb
# frozen_string_literal: true

module Api
  module V1
    class EventsController < ApplicationController
      include ErrorHandling if defined?(ErrorHandling)

      # Public endpoints: MUST bypass global auth if ApplicationController authenticates globally.
      skip_before_action :authenticate_amigo!, only: %i[index show mission_index], raise: false

      # Protected endpoints
      before_action :authenticate_amigo!, only: %i[my_events create update destroy]

      # Verify CSRF only for state-changing requests (matches your Axios behavior)
      before_action :verify_csrf_token, only: %i[create update destroy]

      # But still *mint* a CSRF cookie for public browsing so future mutations can succeed
      after_action :set_csrf_cookie, only: %i[index show my_events]

      before_action :set_event, only: %i[show update destroy]

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      # GET /api/v1/events
      def index
        disable_api_caching!

        events = Event.all.order(created_at: :desc)
        render json: events, each_serializer: EventSerializer, status: :ok
      rescue ActiveRecord::ConnectionNotEstablished
        render json: { error: "Database connection error." }, status: :service_unavailable
      end

      # GET /api/v1/events/:id
      def show
        disable_api_caching!

        render json: @event,
               serializer: EventSerializer,
               include: [:primary_event_location],
               status: :ok
      end

      # POST /api/v1/events
      def create
        policy = EventPolicy.new(current_amigo, nil)
        return render(json: { error: "Unauthorized" }, status: :unauthorized) unless policy.create?

        event = Events::CreateEvent.new.call(creator: current_amigo, attrs: event_params)

        render json: event,
               serializer: EventSerializer,
               include: [:primary_event_location],
               status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
      end

      # PATCH/PUT /api/v1/events/:id
      def update
        return unless authorize_event!(@event, :update?)

        Event.transaction do
          if params[:new_lead_coordinator_id].present?
            roles_policy = EventPolicy.new(current_amigo, @event)
            unless roles_policy.manage_roles?
              render json: { error: "Unauthorized" }, status: :unauthorized
              raise ActiveRecord::Rollback
            end

            new_id = params[:new_lead_coordinator_id].to_i

            @event.event_amigo_connectors.lead_coordinator
                  .where.not(amigo_id: new_id)
                  .delete_all

            @event.event_amigo_connectors
                  .find_or_initialize_by(amigo_id: new_id)
                  .update!(role: :lead_coordinator)

            @event.update!(lead_coordinator_id: new_id)
          end

          raw_params     = event_params.to_h.deep_dup
          location_attrs = raw_params.delete("location") || raw_params.delete(:location)

          @event.update!(raw_params)

          if location_attrs.present?
            Events::UpsertPrimaryLocation.new.call(event: @event, raw_attrs: location_attrs)
          end
        end

        render json: @event,
               serializer: EventSerializer,
               include: [:primary_event_location],
               status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
      end

      # DELETE /api/v1/events/:id
      def destroy
        return unless authorize_event!(@event, :destroy?)

        @event.destroy!
        render json: { message: "Event successfully deleted." }, status: :ok
      rescue ActiveRecord::RecordNotDestroyed => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
      end

      # GET /api/v1/events/my_events
      def my_events
        disable_api_caching!

        coordinator_roles =
          EventAmigoConnector.roles.values_at("lead_coordinator", "assistant_coordinator")

        events = Event
          .left_outer_joins(:event_amigo_connectors)
          .where(
            "events.lead_coordinator_id = :id OR " \
            "(event_amigo_connectors.amigo_id = :id AND event_amigo_connectors.role IN (:roles))",
            id: current_amigo.id,
            roles: coordinator_roles
          )
          .distinct
          .order(created_at: :desc)

        render json: events, each_serializer: EventSerializer, status: :ok
      end

      # GET /api/v1/events/mission
      def mission_index
        render "api/v1/events/mission_index"
      end

      private

      def set_event
        @event = Event.find(params[:id])
      end

      def render_not_found(_e)
        render json: { error: "Event not found" }, status: :not_found
      end

      def authorize_event!(record, action)
        policy = EventPolicy.new(current_amigo, record)
        return true if policy.public_send(action)

        render json: { error: "Unauthorized" }, status: :unauthorized
        false
      end

      def disable_api_caching!
        response.headers["Cache-Control"] = "no-store"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
      end

      # Ensure CSRF cookie exists for browser clients (supports your Axios interceptors).
      def set_csrf_cookie
        token = form_authenticity_token
        cookies["CSRF-TOKEN"] = {
          value: token,
          path: "/",
          secure: request.ssl?,
          same_site: :none
        }
      end

      def event_params
        params.require(:event).permit(
          :event_name,
          :event_type,
          :event_date,
          :event_time,
          :status,
          :description,
          event_speakers_performers: [],
          location: [
            :business_name,
            :business_phone,
            :location_type,
            :street_number,
            :street_name,
            :city,
            :state_province,
            :country,
            :postal_code,
            :postal_code_suffix,
            :owner_name,
            :capacity,
            :capacity_seated,
            :availability_notes,
            :has_food,
            :has_drink,
            :has_internet,
            :has_big_screen,
            :place_id,
            :location_image_attribution,
            :image_url,
            :photo_reference,
            { search_criteria: [], search_venue_types: [] }
          ]
        )
      end
    end
  end
end
