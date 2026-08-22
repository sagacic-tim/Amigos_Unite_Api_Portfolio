# app/controllers/api/v1/amigos_controller.rb
module Api
  module V1
    class AmigosController < ApplicationController
      include ActionController::Cookies
      include ActionController::MimeResponds

      # NOTE: we no longer use Devise's authenticate_amigo! for :me, because
      # our auth is driven by the JWT cookie / Authorization header we manage
      # ourselves (see SessionsController).
      # before_action :authenticate_amigo!, only: [:me]

      before_action :verify_csrf_token, only: [:create, :update, :destroy]

      before_action :set_amigo,        only: [:show, :update, :destroy]
      before_action :authorize_amigo!, only: [:destroy]

      helper_method :current_amigo

      # GET /api/v1/amigos
      # Params:
      #   ?page=1          — page number (default: 1)
      #   ?location=       — filter by city, state, country, or short code
      #   ?event_id=       — (reserved) filter by event attendance
      PER_PAGE = 20

      def index
        scope = Amigo.includes(avatar_attachment: :blob)

        if (loc = params[:location].presence)
          tokens      = loc.split(",").map(&:strip).reject(&:blank?)
          first_token = tokens.first.to_s

          # ── Detect input type ────────────────────────────────────────────────
          #
          # 1. POSTAL CODE  — single all-digit token (e.g. "91120")
          #    → exact postal_code match; returns all amigos in that zip.
          #
          # 2. FULL ADDRESS — first token starts with a street number followed
          #    by street name text (e.g. "3939 S Broadway, Los Angeles, CA")
          #    → proximity-only; geocode + 5-mile radius so exact streets
          #      are never exposed (anonymisation).
          #
          # 3. LOCATION DESCRIPTOR — everything else:
          #    city, state, country in any recognised format.
          #    Short tokens (≤3 chars: "CA", "US") use exact case-insensitive
          #    match against code fields to avoid false positives — e.g. LIKE
          #    "%us%" would wrongly match the city "Houston".
          #    "USA" is normalised to "US" before matching.
          #    Longer tokens use LIKE against full-name fields.

          is_postal_code  = tokens.length == 1 && first_token.match?(/\A\d{3,10}(-\d+)?\z/)
          is_full_address = first_token.match?(/\A\d+\s+\S/)

          if is_postal_code
            # ── Exact zip code match ─────────────────────────────────────────
            scope = scope
              .joins(:amigo_locations)
              .where("amigo_locations.postal_code = ?", first_token)
              .distinct

          elsif is_full_address
            # ── Full address → proximity only ────────────────────────────────
            scope = proximity_scope(scope, loc)

          else
            # ── Location descriptor → token AND search ───────────────────────
            # Normalise "USA" → "US" (stored as country_short "US",
            # not "USA" or "United States")
            normalised = tokens.map { |t| t.match?(/\Ausa\z/i) ? "US" : t }

            text_scope = Amigo.joins(:amigo_locations)
            normalised.each do |token|
              tl = token.downcase
              if token.length <= 3
                # Short code — exact match on code fields only
                text_scope = text_scope.where(
                  "LOWER(amigo_locations.state_province_short) = :t OR
                   LOWER(amigo_locations.country_short) = :t",
                  t: tl
                )
              else
                # Full name — LIKE match on name fields
                text_scope = text_scope.where(
                  "LOWER(amigo_locations.city) LIKE :t OR
                   LOWER(amigo_locations.state_province) LIKE :t OR
                   LOWER(amigo_locations.country) LIKE :t",
                  t: "%#{tl}%"
                )
              end
            end
            scope = scope.where(id: text_scope.distinct.pluck(:id))
          end
        end

        total       = scope.count
        page        = [[params[:page].to_i, 1].max, [(total.to_f / PER_PAGE).ceil, 1].max].min
        page        = 1 if total.zero?
        amigos      = scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE)

        render json: {
          amigos: ActiveModelSerializers::SerializableResource.new(
            amigos,
            each_serializer: AmigoIndexSerializer,
            adapter:         :attributes
          ),
          meta: {
            current_page: page,
            per_page:     PER_PAGE,
            total_count:  total,
            total_pages:  [(total.to_f / PER_PAGE).ceil, 1].max
          }
        }, status: :ok
      end

      # GET /api/v1/amigos/:id
      def show
        render json: @amigo,
               serializer: AmigoSerializer,
               adapter: :attributes,       # ⬅️ same here
               status: :ok
      end

      # POST /api/v1/amigos
      def create
        @amigo = Amigo.new(amigo_params.except(:avatar))

        if (upload = params.dig(:amigo, :avatar)).present?
          if upload.is_a?(ActionDispatch::Http::UploadedFile)
            @amigo.avatar.attach(upload)
            @amigo.avatar_source = 'upload'
          else
            @amigo.attach_avatar_by_identifier(upload)
          end
        else
          attach_default_avatar(@amigo)
        end

        if @amigo.save
          render json: amigo_json(@amigo), status: :created
        else
          render json: @amigo.errors, status: :unprocessable_content
        end
      end

      # PATCH/PUT /api/v1/amigos/:id
      def update
        if params.dig(:amigo, :avatar).present?
          @amigo.avatar_source = 'upload'
        else
          @amigo.avatar_source     = params.dig(:amigo, :avatar_source).presence || @amigo.avatar_source
          @amigo.avatar_remote_url = params.dig(:amigo, :avatar_remote_url).presence if @amigo.avatar_source == 'url'
        end

        if @amigo.update(amigo_params)
          unless @amigo.avatar_source.blank? || @amigo.avatar_source == 'upload'
            ok = @amigo.apply_avatar_preference!
            return render json: { errors: @amigo.errors.full_messages }, status: :unprocessable_content unless ok
          end

          render json: amigo_json(@amigo), status: :ok
        else
          render json: @amigo.errors, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/amigos/:id
      def destroy
        if @amigo.destroy
          render json: { message: 'Amigo deleted successfully' }, status: :ok
        else
          render json: @amigo.errors, status: :unprocessable_content
        end
      end

      # GET /api/v1/me
      #
      # This now mirrors your SessionsController behavior: it reads the
      # JWT from the signed cookie (or Authorization header), decodes it,
      # and returns the current amigo payload, or 401 if anything is wrong.
      def me
        token = cookies.signed[:jwt] || bearer_token

        if token.blank?
          return render json: {
            status: { code: 401, message: 'Missing token' },
            errors: ['Missing token']
          }, status: :unauthorized
        end

        begin
          payload  = JsonWebToken.decode(token) # raises on invalid/expired
          amigo_id = (payload[:sub] || payload['sub']).to_i
          amigo    = Amigo.find(amigo_id)

          render json: {
            status: { code: 200, message: 'OK' },
            data:   { amigo: amigo_json(amigo) }
          }, status: :ok

        rescue JWT::ExpiredSignature
          render json: {
            status: { code: 401, message: 'Token expired' },
            errors: ['Token expired']
          }, status: :unauthorized

        rescue JWT::DecodeError => e
          render json: {
            status: { code: 401, message: 'Invalid token' },
            errors: [e.message]
          }, status: :unauthorized

        rescue ActiveRecord::RecordNotFound
          render json: {
            status: { code: 401, message: 'Amigo not found' },
            errors: ['Amigo not found']
          }, status: :unauthorized
        end
      end

      private

      def set_amigo
        @amigo = Amigo.find(params[:id])
      end

      # Geocode +address_string+ and return +base_scope+ filtered to amigos
      # whose amigo_location is within 5 miles of the geocoded point.
      # Returns base_scope.none on geocoding failure so the caller always gets
      # a valid relation.
      def proximity_scope(base_scope, address_string)
        results = Geocoder.search(address_string)
        if results.any? && results.first.latitude && results.first.longitude
          lat = results.first.latitude
          lng = results.first.longitude

          nearby_ids = AmigoLocation
            .where.not(latitude: nil)
            .where.not(longitude: nil)
            .where(
              "(3959 * acos(GREATEST(-1.0, LEAST(1.0,
                 cos(radians(:lat)) * cos(radians(latitude)) *
                 cos(radians(longitude) - radians(:lng)) +
                 sin(radians(:lat)) * sin(radians(latitude))
               )))) <= :radius",
              lat: lat, lng: lng, radius: 5.0
            )
            .pluck(:amigo_id)

          base_scope.where(id: nearby_ids)
        else
          Rails.logger.warn("[AmigosController] Could not geocode address: #{address_string.inspect}")
          base_scope.none
        end
      rescue => e
        Rails.logger.warn("[AmigosController] Geocoding failed for #{address_string.inspect}: #{e.message}")
        base_scope.none
      end

      # Single, reusable JSON shape (prevents leaking internal columns)
      def amigo_json(amigo)
        amigo.as_json(only: %i[id user_name email first_name last_name])
             .merge(avatar_url: amigo.avatar_url_with_buster)
      end

      def attach_default_avatar(amigo)
        path = Rails.root.join("public/images/default-amigo-avatar.png")
        amigo.avatar.attach(io: File.open(path), filename: "default-amigo-avatar.png", content_type: "image/png") if File.exist?(path)
      end

      def amigo_params
        params.require(:amigo).permit(
          :first_name, :last_name, :user_name, :email, :secondary_email,
          :phone_1, :phone_2,            # ⬅️ use the real columns
          :password,
          :avatar,
          :avatar_source,
          :avatar_remote_url
        )
      end

      # Mirror SessionsController's helper so we can also accept Authorization: Bearer ...
      def bearer_token
        request.headers['Authorization']&.split(' ')&.last
      end
    end
  end
end
