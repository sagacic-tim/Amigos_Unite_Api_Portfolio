# app/controllers/api/v1/event_amigo_connectors_controller.rb
# frozen_string_literal: true

module Api
  module V1
    class EventAmigoConnectorsController < ApplicationController
      before_action :authenticate_amigo!
      before_action :verify_csrf_token, only: %i[create update destroy]

      before_action :set_event
      before_action :set_event_amigo_connector, only: %i[show update destroy]
      before_action :set_target_amigo,          only: %i[create update destroy]

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ::NotAuthorizedError,         with: :render_unauthorized
      rescue_from ArgumentError,                with: :render_unprocessable

      def index
        connectors = @event.event_amigo_connectors.includes(amigo: :amigo_detail)

        render json: connectors,
               each_serializer: EventAmigoConnectorSerializer,
               adapter: :attributes,
               status: :ok
      end

      def show
        render json: @event_amigo_connector,
               serializer: EventAmigoConnectorSerializer,
               adapter: :attributes,
               status: :ok
      end

      def create
        return render(json: { error: "amigo_id is required" }, status: :unprocessable_content) unless @target_amigo

        can_manage = EventPolicy.new(current_amigo, @event).manage_connectors?
        self_join  = current_amigo.id == @target_amigo.id
        return render_unauthorized unless can_manage || self_join

        role = resolved_role || :participant

        connector = @event.event_amigo_connectors.new(amigo: @target_amigo, role: role)

        if connector.save
          render json: connector,
                 serializer: EventAmigoConnectorSerializer,
                 adapter: :attributes,
                 status: :created
        else
          render json: { errors: connector.errors.full_messages },
                 status: :unprocessable_content
        end
      end

      def update
        target = @target_amigo || @event_amigo_connector&.amigo
        return render(json: { error: "Target not found" }, status: :unprocessable_content) unless target

        role_sym = resolved_role
        return render(json: { error: "Role param is required" }, status: :unprocessable_content) unless role_sym

        valid_roles = EventAmigoConnector.roles.keys.map!(&:to_sym)
        unless valid_roles.include?(role_sym)
          return render json: { error: "Invalid role. Allowed: #{valid_roles.join(', ')}" },
                        status: :unprocessable_content
        end

        conn =
          begin
            if role_sym == :lead_coordinator
              Events::TransferLead.new.call(
                actor:    current_amigo,
                event:    @event,
                new_lead: target
              )
            else
              Events::ChangeRole.new.call(
                actor:    current_amigo,
                event:    @event,
                target:   target,
                new_role: role_sym
              )
            end
          rescue => e
            # Critical: survives "NotAuthorizedError" constant reassignment.
            return render_unauthorized if e.class.name == "NotAuthorizedError"
            raise
          end

        render json: conn,
               serializer: EventAmigoConnectorSerializer,
               adapter: :attributes,
               status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages },
               status: :unprocessable_content
      end

      def destroy
        can_manage = EventPolicy.new(current_amigo, @event).manage_connectors?

        connector =
          if @event_amigo_connector
            @event_amigo_connector
          elsif @target_amigo
            @event.event_amigo_connectors.find_by!(amigo_id: @target_amigo.id)
          else
            return render json: { error: "Connector not found" }, status: :not_found
          end

        self_owner = current_amigo.id == connector.amigo_id
        return render_unauthorized unless can_manage || self_owner

        connector.destroy!
        head :no_content
      end

      private

      def set_event
        @event = Event.find(params[:event_id])
      end

      def set_event_amigo_connector
        @event_amigo_connector = @event.event_amigo_connectors.find(params[:id])
      end

      def set_target_amigo
        amigo_id = params.dig(:event_amigo_connector, :amigo_id) || params[:amigo_id]
        @target_amigo = Amigo.find_by(id: amigo_id) if amigo_id.present?
      end

      def resolved_role
        raw = params.dig(:event_amigo_connector, :role) || params[:role]
        raw.present? ? raw.to_s.strip.downcase.to_sym : nil
      end

      def render_not_found(e)
        render json: { error: e.message }, status: :not_found
      end

      def render_unauthorized(_e = nil)
        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def render_unprocessable(e)
        render json: { error: e.message }, status: :unprocessable_content
      end
    end
  end
end
