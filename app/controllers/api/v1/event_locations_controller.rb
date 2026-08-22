# app/controllers/api/v1/event_locations_controller.rb

class Api::V1::EventLocationsController < ApplicationController
  before_action :set_event, only: [:index], if: -> { params[:event_id].present? }
  before_action :set_event_location, only: [:show, :update, :destroy, :store_location_image]

  # GET /events/:event_id/event_locations or /event_locations
  def index
    if @event
      @event_locations = @event.event_locations
    else
      @event_locations = EventLocation.all
    end
    render :index
  end

  # GET /api/v1/event_locations/:id
  def show
    event_location = EventLocation.find(params[:id])

    render json: event_location.as_json(
      only: %i[
        id
        business_name
        address
        city
        state_province_short
        postal_code
        country
        status
        location_type
        location_image_attribution
      ],
      methods: %i[location_image_url]
    )
  end

  # POST /api/v1/event_locations
  def create
    @event_location = EventLocation.new(event_location_params)

    if @event_location.save
      render :create, status: :created
    else
      render json: @event_location.errors, status: :unprocessable_content
    end
  end 

  # PATCH/PUT /api/v1/event_locations/:id
  def update
    if @event_location.update(event_location_params)
      render :update
    else
      render json: @event_location.errors, status: :unprocessable_content
    end
  end

  # POST /api/v1/event_locations/:id/store_location_image
  #
  # Downloads a Google Places photo by photo_reference and attaches it
  # to this EventLocation via Active Storage, then returns the stored URL.
  #
  # Body params:
  #   photo_reference  String  (required)
  #   attribution      String  (optional — HTML attribution from Google)
  def store_location_image
    photo_reference = params[:photo_reference].to_s.strip
    attribution     = params[:attribution].to_s.strip

    if photo_reference.blank?
      return render json: { error: "photo_reference is required" }, status: :unprocessable_entity
    end

    client    = GooglePlaces::Client.new
    photo_url = client.send(:build_photo_url, photo_reference, max_width: 1200)

    # Download the image (Google redirects to the actual CDN URL)
    response = HTTParty.get(photo_url, follow_redirects: true)

    unless response.success?
      return render json: { error: "Failed to download photo" }, status: :bad_gateway
    end

    content_type = response.headers["content-type"]&.split(";")&.first || "image/jpeg"
    extension    = content_type.split("/").last.gsub("jpeg", "jpg")
    filename     = "location_#{@event_location.id}_#{SecureRandom.hex(6)}.#{extension}"

    @event_location.location_image.attach(
      io:           StringIO.new(response.body),
      filename:     filename,
      content_type: content_type
    )

    @event_location.update_column(:location_image_attribution, attribution) if attribution.present?

    ProcessLocationImageJob.perform_later(@event_location.id)

    render json: {
      image_url:   @event_location.location_image_url,
      attribution: attribution
    }, status: :ok

  rescue GooglePlaces::Error => e
    render json: { error: e.message }, status: (e.http_code || 502)
  rescue StandardError => e
    Rails.logger.error("[EventLocationsController#store_location_image] #{e.class}: #{e.message}")
    render json: { error: "Image storage failed" }, status: :service_unavailable
  end

  # DELETE /api/v1/event_locations/:id
  def destroy
    if @event_location.event_location_connectors.exists?
      event_ids = @event_location.events.pluck(:id)
      render json: {
        warning: "This location is currently associated with Event(s) ##{event_ids.join(', ')}. Are you sure you want to delete this location?",
        event_ids: event_ids
      }, status: :forbidden
    elsif @event_location.destroy
      render json: { message: 'Event location successfully deleted.' }, status: :ok
    else
      render json: { error: 'Failed to delete event location.' }, status: :unprocessable_content
    end
  end

  private

  def set_event
    @event = Event.find_by(id: params[:event_id])
    return if @event
    render json: { error: 'Event not found' }, status: :not_found
  end

  def set_event_location
    @event_location = EventLocation.find_by(id: params[:id])
    return if @event_location
    render json: { error: 'Event Location not found' }, status: :not_found
  end

  def event_location_params
    params.require(:event_location).permit(
      :business_name,
      :business_phone,
      :address,
      :floor,
      :street_number,
      :street_name,
      :room_no,
      :apartment_suite_number,
      :city_sublocality,
      :city,
      :state_province_subdivision,
      :state_province,
      :state_province_short,
      :country,
      :country_short,
      :postal_code,
      :postal_code_suffix,
      :post_box,
      :latitude,
      :longitude,
      :time_zone,
      :location_type,          # ← NEW: persisted category
      :owner_name,
      :capacity,
      :capacity_seated,
      :availability_notes,
      :has_food,
      :has_drink,
      :has_internet,
      :has_big_screen,
      :place_id,
      :location_image_attribution
      # If/when you decide to send a JSON services hash directly:
      # services: {}
    )
  end
end
