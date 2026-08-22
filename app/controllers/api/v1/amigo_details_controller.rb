# app/controllers/api/v1/amigo_details_controller.rb
class Api::V1::AmigoDetailsController < ApplicationController
  before_action :authenticate_amigo!
  before_action :set_amigo
  before_action :set_amigo_detail, only: [:show, :update, :destroy]

  # DEV-ONLY: return JSON with the real exception.
  rescue_from(StandardError) do |e|
    raise e unless Rails.env.development?
    Rails.logger.error(
      "[AmigoDetails] #{e.class}: #{e.message}\n" \
      "#{Array(e.backtrace).first(10).join("\n")}"
    )
    render json: {
      error: e.class.to_s,
      message: e.message,
      request_id: request.request_id,
      params_shape: params.to_unsafe_h.transform_values { |v| v.class.name }
    }, status: :internal_server_error
  end

  # GET /api/v1/amigos/:amigo_id/amigo_detail
  def show
    if @amigo_detail
      render json: @amigo_detail,
             serializer: AmigoDetailSerializer,
             adapter: :attributes, # <- drop JSON:API + kebab-case
             status: :ok
    else
      render json: { error: "No details found" }, status: :not_found
    end
  end

  # POST /api/v1/amigos/:amigo_id/amigo_detail
  def create
    if @amigo_detail
      return update
    end

    detail = @amigo.build_amigo_detail(amigo_detail_params)
    if detail.save
      render json: detail,
             serializer: AmigoDetailSerializer,
             adapter: :attributes,
             status: :created
    else
      render json: detail.errors, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/v1/amigos/:amigo_id/amigo_detail
  def update
    @amigo_detail ||= @amigo.build_amigo_detail

    if @amigo_detail.update(amigo_detail_params)
      status = @amigo_detail.previous_changes.key?('id') ? :created : :ok
      render json: @amigo_detail,
             serializer: AmigoDetailSerializer,
             adapter: :attributes,
             status: status
    else
      render json: @amigo_detail.errors, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/amigos/:amigo_id/amigo_detail
  def destroy
    if @amigo_detail
      @amigo_detail.destroy
      head :no_content
    else
      render json: { error: 'No details found' }, status: :not_found
    end
  end

  private

  def set_amigo
    @amigo = Amigo.find_by(id: params[:amigo_id])
    unless @amigo
      render json: { error: 'Amigo not found' }, status: :not_found
      return
    end
  end

  def set_amigo_detail
    @amigo_detail = @amigo&.amigo_detail
  end

  # Accepts both wrapped and unwrapped payloads
  def amigo_detail_params
    container =
      if params[:amigo_detail].is_a?(ActionController::Parameters)
        params.require(:amigo_detail)
      else
        ActionController::Parameters.new(params.permit!.to_h)
      end

    permitted = container.permit(
      :date_of_birth,
      :member_in_good_standing,
      :available_to_host,
      :willing_to_help,
      :willing_to_donate,
      :personal_bio
    )

    if permitted.key?(:date_of_birth) && permitted[:date_of_birth].respond_to?(:strip) &&
      permitted[:date_of_birth].strip == ""
      permitted[:date_of_birth] = nil
    end

    permitted
  end
end
