# app/controllers/api/v1/amigo_locations_controller.rb
class Api::V1::AmigoLocationsController < ApplicationController
  include ErrorHandling  # keep your shared error handling

  before_action :authenticate_amigo!
  before_action :verify_csrf_token, only: [:create, :update, :destroy]

  # We need @amigo for all nested routes; your routes are:
  # /api/v1/amigos/:amigo_id/amigo_locations[/:id]
  before_action :set_amigo, only: [:index, :show, :create, :update, :destroy]
  before_action :set_amigo_location, only: [:show, :update, :destroy]

  # GET /api/v1/amigos/:amigo_id/amigo_locations
  def index
    # Always return an array (possibly empty). The FE does:
    # const list = Array.isArray(l?.data) ? l.data : (l?.data?.data ?? []);
    locations = @amigo.amigo_locations.includes(:amigo)
    render json: locations.as_json(include: :amigo), status: :ok
  end

  # GET /api/v1/amigos/:amigo_id/amigo_locations/:id
  def show
    # set_amigo_location renders 404 if not found
    render json: @amigo_location, status: :ok
  end

  # POST /api/v1/amigos/:amigo_id/amigo_locations
  def create
    location = @amigo.amigo_locations.build(location_params)
    if location.save
      render json: location, status: :created
    else
      render json: location.errors, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/v1/amigos/:amigo_id/amigo_locations/:id
  def update
    # set_amigo_location renders 404 if not found
    if @amigo_location.update(location_params)
      render json: @amigo_location, status: :ok
    else
      render json: @amigo_location.errors, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/amigos/:amigo_id/amigo_locations/:id
  def destroy
    # set_amigo_location renders 404 if not found
    @amigo_location.destroy
    head :no_content
  end

  private

  def set_amigo
    @amigo = Amigo.find(params[:amigo_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Amigo not found' }, status: :not_found
  end

  def set_amigo_location
    @amigo_location = @amigo.amigo_locations.find_by(id: params[:id])
    return if @amigo_location.present?

    render json: { error: 'Location not found' }, status: :not_found
  end

  # Keep these keys in sync with what your FE sends/saves.
  def location_params
    params.require(:amigo_location).permit(
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
      :time_zone
    )
  end
end
