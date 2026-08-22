# app/controllers/api/v1/event_location_connectors_controller.rb
class Api::V1::EventLocationConnectorsController < ApplicationController
  before_action :set_event
  before_action :set_event_location_connector, only: [:show, :update, :destroy]

  # GET /api/v1/events/:event_id/event_location_connectors
  def index
    connectors = @event.event_location_connectors.includes(:event_location)
    render json: connectors.as_json(include: :event_location), status: :ok
  end

  # GET /api/v1/events/:event_id/event_location_connectors/:id
  def show
    render json: @event_location_connector.as_json(include: :event_location), status: :ok
  end

  # POST /api/v1/events/:event_id/event_location_connectors
  def create
    return unless ensure_can_manage_locations!

    event_location = EventLocation.find_by(id: event_location_connector_params[:event_location_id])
    return render json: { error: 'Event location not found' }, status: :not_found unless event_location

    connector = EventLocationConnector.find_or_initialize_by(
      event_id: @event.id,
      event_location_id: event_location.id
    )

    # If the relationship already exists, optionally flip to primary if requested.
    if connector.persisted?
      if cast_bool(params.dig(:event_location_connector, :is_primary))
        EventLocationConnector.transaction do
          @event.event_location_connectors.update_all(is_primary: false)
          connector.update!(is_primary: true)
        end
        return render json: connector, status: :ok
      end
      return render json: { message: 'Location already connected to this event' }, status: :ok
    end

    # New connector being created
    make_primary = cast_bool(params.dig(:event_location_connector, :is_primary))
    make_primary ||= !@event.event_location_connectors.exists?(is_primary: true) # default if none yet

    EventLocationConnector.transaction do
      if make_primary
        @event.event_location_connectors.update_all(is_primary: false)
        connector.is_primary = true
      end
      connector.save!
    end

    render json: connector, status: :created

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique
    # Partial unique index conflict (another request won the race for primary)
    connector.is_primary = false
    connector.save!
    render json: connector, status: :created
  end

  # PATCH/PUT /api/v1/events/:event_id/event_location_connectors/:id
  def update
    return unless ensure_can_manage_locations!

    if @event_location_connector.event_id != @event.id
      return render json: { error: "Connector does not belong to the specified event" }, status: :forbidden
    end

    wants_primary = cast_bool(params.dig(:event_location_connector, :is_primary))

    EventLocationConnector.transaction do
      if wants_primary
        @event.event_location_connectors.where.not(id: @event_location_connector.id)
              .update_all(is_primary: false)
        @event_location_connector.is_primary = true
      end

      @event_location_connector.update!(event_location_connector_params.except(:is_primary))
    end

    render json: @event_location_connector, status: :ok

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique
    # Another request set a primary concurrently; keep this one non-primary and still update other fields.
    @event.event_location_connectors.reload # optional clarity
    @event_location_connector.update!(event_location_connector_params.except(:is_primary))
    render json: @event_location_connector, status: :ok
  end

  # DELETE /api/v1/events/:event_id/event_location_connectors/:id
  def destroy
    return unauthorized! unless EventPolicy.new(current_amigo, @event).manage_locations?

    if @event_location_connector.destroy
      render json: { message: 'Event Location Connector successfully deleted' }, status: :ok
    else
      render json: { error: @event_location_connector.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end

  private

  def set_event
    @event = Event.find_by(id: params[:event_id])
    return render json: { error: 'Event not found' }, status: :not_found unless @event
  end

  def ensure_can_manage_locations!
    allowed = EventPolicy.new(current_amigo, @event).manage_locations?
    return true if allowed
    render json: { error: 'Unauthorized' }, status: :unauthorized
    false
  end

  def set_event_location_connector
    @event_location_connector = @event.event_location_connectors.find_by(id: params[:id])
    return render json: { error: 'Event Location Connector not found' }, status: :not_found unless @event_location_connector
  end

  def event_location_connector_params
    params.require(:event_location_connector).permit(:event_location_id, :is_primary)
  end

  def unauthorized!
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def cast_bool(val)
    ActiveModel::Type::Boolean.new.cast(val)
  end
end
