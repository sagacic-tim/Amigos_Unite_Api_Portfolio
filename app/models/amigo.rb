# app/models/amigo.rb
require "digest/md5"
require "open-uri"
require "image_processing/vips"
require "stringio"

class Amigo < ApplicationRecord
  # === Associations ===
  has_one_attached :avatar
  has_one  :amigo_detail,    dependent: :destroy
  has_many :amigo_locations, dependent: :destroy
  has_many :lead_coordinator_for_events, class_name: "Event", foreign_key: "lead_coordinator_id"
  has_many :event_amigo_connectors
  has_many :events, through: :event_amigo_connectors

  # === Devise Modules ===
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :lockable, :timeoutable, :confirmable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Virtual attribute used by Devise (see devise initializer)
  attr_accessor :login_attribute

  # === Avatar source columns expected ===
  # t.string   :avatar_source
  # t.string   :avatar_remote_url
  # t.datetime :avatar_synced_at
  AVATAR_SOURCES = %w[upload gravatar url default].freeze

  # Max remote avatar download size
  MAX_REMOTE_AVATAR_BYTES = 5.megabytes

  # Custom error to stop retries for oversize responses
  class MaxRemoteAvatarSizeExceeded < StandardError; end

  # === Validations ===
  validates :first_name, :last_name,
            presence: true,
            length:   { maximum: 50 }

  validates :user_name,
            presence: true,
            uniqueness: { case_sensitive: false },
            length: { maximum: 50 },
            format: { with: /\A[a-zA-Z0-9_.'-]+\z/ }

  validates :email,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :secondary_email,
            allow_blank: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :phone_1,
            uniqueness: true,
            allow_blank: true,
            format: { with: /\A\+\d{6,15}\z/ }

  validates :phone_2,
            uniqueness: true,
            allow_blank: true,
            format: { with: /\A\+\d{6,15}\z/ }

  validates :avatar,
            content_type: ["image/png", "image/jpg", "image/jpeg", "image/svg+xml", "image/webp"]

  # validate :at_least_one_identifier_present # optional custom rule

  # === Callbacks ===
  before_validation :normalize_identifiers

  # Normalize any newly attached avatar to 200x200 PNG once (guarded inside method).
  after_commit :process_avatar, if: -> { avatar.attached? }, on: %i[create update]

  # After create: attach a default immediately, then queue gravatar/url fetch in background.
  after_commit :ensure_initial_avatar, on: :create

  # === Devise finder (username/email/phone) ===
  def self.find_for_database_authentication(warden_conditions)
    raw = warden_conditions[:login_attribute].to_s.strip
    return nil if raw.blank?

    login_down = raw.downcase
    phone_norm = normalize_phone(raw)

    where(
      "LOWER(user_name) = :login OR LOWER(email) = :login OR phone_1 = :phone OR phone_2 = :phone",
      login: login_down, phone: phone_norm
    ).first
  end

  # === Roles / helpers ===
  enum role: { amigo: 0, staff: 1, admin: 2 }

  # Prefer enum over legacy boolean columns if present.
  def admin?
    self.role == "admin" || respond_to?(:is_admin) && is_admin
  end

  def lead_coordinator_for?(event)
    event_amigo_connectors.exists?(event_id: event.id, role: "lead_coordinator")
  end

  def assistant_coordinator_for?(event)
    event_amigo_connectors.exists?(event_id: event.id, role: "assistant_coordinator")
  end

  def can_remove_participant?(event)
    lead_coordinator_for?(event) || assistant_coordinator_for?(event)
  end

  def can_manage?(amigo)
    amigo && id == amigo.id
  end

  def event_roles
    event_amigo_connectors.includes(:event).map { |c| { event_id: c.event_id, role: c.role } }
  end

  # === Avatar helpers ===

  def avatar_url_with_buster
    if avatar.attached?
      path  = Rails.application.routes.url_helpers.rails_blob_path(avatar, only_path: true)
      stamp = (avatar_synced_at || updated_at)&.to_i
      stamp ? "#{path}?v=#{stamp}" : path
    else
      # ⬅️ fallback when nothing is attached yet
      gravatar_url(size: 200) || "/images/default-amigo-avatar.png"
    end
  end

  def as_json(options = {})
    super(options).merge(
      phone_1: international_phone(phone_1),
      phone_2: international_phone(phone_2),
      avatar_url: avatar_url_with_buster
    )
  end

  # Relative path for frontend to prefix with API origin.
  def avatar_url
    Rails.application.routes.url_helpers.rails_blob_path(avatar, only_path: true) if avatar.attached?
  end

  # Attach a pre-seeded avatar by identifier (used by seeds/helpers).
  def attach_avatar_by_identifier(avatar_identifier)
    avatar_path = Rails.root.join("lib/seeds/avatars", "#{avatar_identifier}.svg")
    if File.exist?(avatar_path)
      avatar.attach(io: File.open(avatar_path), filename: "#{avatar_identifier}.svg", content_type: "image/svg+xml")
    else
      errors.add(:avatar, "specified avatar does not exist")
    end
  end

  # Build a gravatar URL (we default to identicon for missing images).
  def gravatar_url(size: 200)
    return nil if email.blank?
    hash = Digest::MD5.hexdigest(email.strip.downcase)
    "https://www.gravatar.com/avatar/#{hash}?s=#{size}&d=identicon"
  end

  # Try to fetch/attach Gravatar (returns true if attached).
  def attach_gravatar
    u = gravatar_url(size: 200)
    return false unless u
    attach_remote_image(u) ||
    attach_remote_image(u.sub('www.gravatar.com', 'seccdn.libravatar.org'))
  end

  # Download an image from URL and attach to ActiveStorage (defensive).
  def attach_remote_image(url)
    return false unless url.to_s =~ /\Ahttps?:\/\//i

    # Enforce size limits both via declared Content-Length and while streaming
    remote_io = URI.open(
      url, "rb",
      read_timeout: 8,
      open_timeout: 8,
      content_length_proc: ->(len) {
        raise MaxRemoteAvatarSizeExceeded, "Avatar larger than #{MAX_REMOTE_AVATAR_BYTES} bytes" if len && len > MAX_REMOTE_AVATAR_BYTES
      },
      progress_proc: ->(bytes) {
        raise MaxRemoteAvatarSizeExceeded, "Avatar larger than #{MAX_REMOTE_AVATAR_BYTES} bytes" if bytes && bytes > MAX_REMOTE_AVATAR_BYTES
      }
    )

    content_type = remote_io.content_type.to_s.downcase

    # Fallback sniff if server doesn't send a good content-type
    if content_type.blank? || content_type == "application/octet-stream"
      data = remote_io.read
      name = File.basename(URI.parse(url).path) rescue "remote_avatar"
      content_type = Marcel::MimeType.for(StringIO.new(data), name: name).to_s.downcase
      remote_io = StringIO.new(data) # re-wrap for ActiveStorage
    end

    return false unless content_type.start_with?("image/")

    ext =
      if content_type.include?("png")         then "png"
      elsif content_type.include?("jpeg") ||
            content_type.include?("jpg")      then "jpg"
      elsif content_type.include?("svg")      then "svg"
      elsif content_type.include?("webp")     then "webp"
      else "bin"
      end

    avatar.attach(io: remote_io, filename: "remote_avatar.#{ext}", content_type: content_type)
    true

  rescue OpenURI::HTTPError => e
    # Treat only 404 as a clean miss; re-raise others so job retries
    if e.io.respond_to?(:status) && e.io.status&.first == "404"
      false
    else
      raise
    end
  rescue MaxRemoteAvatarSizeExceeded => e
    errors.add(:avatar, e.message)
    false
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError, URI::InvalidURIError
    # Let ActiveJob retry_on handle transient network issues
    raise
  rescue => e
    Rails.logger.warn("attach_remote_image failed: #{e.class}: #{e.message}")
    false
  end

  # Attach default avatar blob if present and nothing attached.
  def attach_default_avatar
    return if avatar.attached?
    path = Rails.root.join("public/images/default-amigo-avatar.png")
    return unless File.exist?(path)
    avatar.attach(io: File.open(path), filename: "default-amigo-avatar.png", content_type: "image/png")
  end

  # Users choose avatar source; we enqueue background fetches instead of doing network inline.
  # Controller should set avatar_source and (optionally) avatar_remote_url, then call this.
  def apply_avatar_preference!
    case avatar_source
    when "upload"
      # File already attached by controller (multipart).
      touch(:avatar_synced_at)
    when "gravatar"
      FetchRemoteAvatarJob.perform_later(id, source: "gravatar")
    when "url"
      return errors.add(:avatar_remote_url, "can't be blank") && false if avatar_remote_url.blank?
      FetchRemoteAvatarJob.perform_later(id, source: "url", url: avatar_remote_url)
    else # "default" or nil
      attach_default_avatar
    end
    true
  end

  # === Devise mailer ===
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end 

  private

  # Optional: if you ever allow login without email/username.
  def at_least_one_identifier_present
    if [user_name, email, phone_1, phone_2].all?(&:blank?)
      errors.add(:base, "Provide at least one of username, email, or phone.")
    end
  end

  def normalize_identifiers
    self.user_name = user_name&.strip
    self.email     = email&.strip&.downcase
    self.phone_1   = self.class.normalize_phone(phone_1)
    self.phone_2   = self.class.normalize_phone(phone_2)
  end

  def self.normalize_phone(value)
    return nil if value.blank?
    Phonelib.parse(value).e164.presence
  end

  def international_phone(phone)
    phone.present? ? Phonelib.parse(phone).international : nil
  end

  # Avoid repeated processing and skip SVGs; purge old blob after reattach.
  def process_avatar
    blob = avatar.blob
    return unless blob&.content_type.to_s.start_with?("image/")
    return if blob.content_type == "image/svg+xml"

    meta = blob.metadata.to_h
    return if meta["processed"] == true || meta["processed_avatar"] == true

    old_blob = blob

    avatar.open do |io|
      processed = ImageProcessing::Vips
                    .source(io)
                    .resize_to_fill(200, 200)  # square thumbnail
                    .convert("png")
                    .call

      new_metadata = meta.merge("processed" => true)

      avatar.attach(
        io:           File.open(processed.path),
        filename:     "avatar.png",
        content_type: "image/png",
        metadata:     new_metadata
      )
    end

    touch(:avatar_synced_at)
    old_blob.purge_later

    # Moderate the newly processed avatar in the background.
    # Image is purged automatically if it fails Vision SafeSearch.
    ModerateImageJob.perform_later('Amigo', id, 'avatar')
  rescue => e
    Rails.logger.error "Avatar processing failed for Amigo ##{id}: #{e.message}"
  end

  # After create: show something immediately; then have the job replace it if available.
  def ensure_initial_avatar
    return if avatar.attached?

    self.avatar_source ||= "gravatar"
    attach_default_avatar
    FetchRemoteAvatarJob.perform_later(id, source: avatar_source)
    touch(:avatar_synced_at)
  end
end
