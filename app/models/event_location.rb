# app/models/event_location.rb
class EventLocation < ApplicationRecord
  include GeocodableWithFallback

  # ====================
  # Venue categorization
  # ====================

  VENUE_KEYWORDS = [
    # core venue words
    'restaurant', 'cafe', 'coffee shop', 'tea house',
    'bar', 'pub', 'club',
    'banquet hall', 'event venue',
    'conference center', 'convention center',
    'community center', 'civic center', 'cultural center',
    'recreation center', 'leisure center',

    # performance / culture
    'theater', 'auditorium', 'amphitheater',
    'concert hall',

    # hospitality
    'hotel', 'motel', 'inn',
    'resort', 'lodge',

    # religious
    'church', 'cathedral', 'temple', 'mosque', 'synagogue',
    'abbey', 'basilica', 'parish', 'gurudwara',

    # education / institutional
    'school', 'college', 'university', 'library',
    'training center', 'learning center', 'student union',

    # outdoor
    'park', 'campground',
    'picnic ground'
  ].freeze

  # Infer location_type automatically from business_name if not set manually.
  before_validation :infer_location_type, if: -> { location_type.blank? && business_name.present? }

  # ====================
  # Associations
  # ====================
  has_many :event_location_connectors, dependent: :destroy
  has_many :events, through: :event_location_connectors
  has_many_attached :images
  has_one_attached :location_image

  # If you want typed access to services:
  def services_hash
    (services || {}).symbolize_keys
  end

  def service_enabled?(key)
    !!services_hash[key.to_sym]
  end

  def location_image_url
    return unless location_image.attached?

    Rails.application.routes.url_helpers.url_for(location_image)
  end

  # ====================
  # Enums
  # ====================
  enum status: {
    pending: 0,
    verified: 1,
    rejected: 2
  }

  # ====================
  # Validations
  # ====================
  validates :business_name, length: { maximum: 64 }
  validates :business_phone, length: { maximum: 15 }

  validates :floor, length: { maximum: 10 }
  validates :room_no, :apartment_suite_number, :street_number, length: { maximum: 32 }
  validates :street_name, :city_sublocality, :state_province_subdivision, length: { maximum: 96 }
  validates :city, length: { maximum: 64 }
  validates :state_province, length: { maximum: 32 }
  validates :state_province_short, length: { maximum: 8 }
  validates :country, length: { maximum: 32 }
  validates :country_short, length: { maximum: 3 }
  validates :postal_code, length: { maximum: 12 }
  validates :postal_code_suffix, length: { maximum: 6 }
  validates :post_box, length: { maximum: 12 }
  validates :time_zone, length: { maximum: 48 }

  # Allow nil if geocoding may populate later; make strict if you require presence.
  validates :latitude,
    numericality: { greater_than_or_equal_to: -90,  less_than_or_equal_to: 90 },
    allow_nil: true

  validates :longitude,
    numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 },
    allow_nil: true

  MAX_SEARCH_CRITERIA    = 5
  MAX_SEARCH_VENUE_TYPES = 3

  validate :search_criteria_within_limit
  validate :search_venue_types_within_limit
  validate :search_venue_types_are_known_categories

  # ====================
  # Class-level helpers
  # ====================

  # Returns true if the given name appears to be a "venue" based on the keyword list.
  def self.venue_category?(name)
    return false if name.blank?

    downcased = name.to_s.downcase
    VENUE_KEYWORDS.any? { |kw| downcased.include?(kw) }
  end

  # Returns a title-cased category string derived from the first matched keyword,
  # e.g. "restaurant" => "Restaurant", "community center" => "Community Center".
  def self.infer_location_type_from(name)
    return nil if name.blank?

    downcased = name.to_s.downcase
    match = VENUE_KEYWORDS.find { |kw| downcased.include?(kw) }
    match&.split&.map(&:capitalize)&.join(" ")
  end

  private

  # Populate location_type from business_name if we can infer a category.
  def infer_location_type
    self.location_type ||= self.class.infer_location_type_from(business_name)
  end

  def search_criteria_within_limit
    return if search_criteria.blank? || search_criteria.size <= MAX_SEARCH_CRITERIA
    errors.add(:search_criteria, "may include at most #{MAX_SEARCH_CRITERIA} items")
  end

  def search_venue_types_within_limit
    return if search_venue_types.blank? || search_venue_types.size <= MAX_SEARCH_VENUE_TYPES
    errors.add(:search_venue_types, "may include at most #{MAX_SEARCH_VENUE_TYPES} items")
  end

  def search_venue_types_are_known_categories
    return if search_venue_types.blank?

    unknown = search_venue_types - GooglePlaces::AiLocationSuggestions::VENUE_CATEGORIES.keys
    errors.add(:search_venue_types, "contains unknown venue types: #{unknown.join(', ')}") if unknown.any?
  end
end
