# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_07_07_051440) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false, comment: "Name of the attachment (e.g., avatar, image)"
    t.string "record_type", null: false
    t.bigint "record_id", null: false, comment: "Polymorphic association to the attached model (e.g., Amigo)"
    t.bigint "blob_id", null: false, comment: "Reference to the blob containing actual file data"
    t.datetime "created_at", null: false, comment: "Timestamp when attachment was created"
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false, comment: "Unique key identifier for the blob"
    t.string "filename", null: false, comment: "Original filename of the uploaded file"
    t.string "content_type", comment: "MIME type of the file (e.g., image/png)"
    t.text "metadata", comment: "Serialized metadata (dimensions, etc.)"
    t.string "service_name", null: false, comment: "Name of the Active Storage service used"
    t.bigint "byte_size", null: false, comment: "Size of the file in bytes"
    t.string "checksum", comment: "Base64-encoded checksum of the file"
    t.datetime "created_at", null: false, comment: "Timestamp when blob was created"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false, comment: "Reference to the original blob for which variant is generated"
    t.string "variation_digest", null: false, comment: "Digest of the transformation instructions"
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "amigo_details", force: :cascade do |t|
    t.date "date_of_birth", comment: "Date of birth of the Amigo"
    t.boolean "member_in_good_standing", comment: "Indicates whether the Amigo is in good standing"
    t.boolean "available_to_host", comment: "Whether the Amigo is available to host others"
    t.boolean "willing_to_help", comment: "Whether the Amigo is willing to provide general help"
    t.boolean "willing_to_donate", comment: "Whether the Amigo is willing to contribute donations"
    t.text "personal_bio", comment: "A short personal biography of the Amigo"
    t.bigint "amigo_id", null: false, comment: "Foreign key reference to the Amigo record"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["amigo_id"], name: "index_amigo_details_on_amigo_id"
  end

  create_table "amigo_locations", force: :cascade do |t|
    t.bigint "amigo_id", null: false, comment: "Foreign key reference to the Amigo record"
    t.string "address", limit: 256, comment: "Full formatted address"
    t.string "floor", limit: 10, comment: "Floor number (if applicable)"
    t.string "street_number", limit: 32, comment: "Street number of the address"
    t.string "street_name", limit: 96, comment: "Street name of the address"
    t.string "room_no", limit: 32, comment: "Room number (e.g., hotel or dormitory)"
    t.string "apartment_suite_number", limit: 32, comment: "Apartment or suite number"
    t.string "city_sublocality", limit: 96, comment: "Neighborhood, district, or sublocality within the city"
    t.string "city", limit: 64, comment: "City of the address"
    t.string "state_province_subdivision", limit: 96, comment: "County or sub-region within the state/province"
    t.string "state_province", limit: 32, comment: "Full state or province name"
    t.string "state_province_short", limit: 8, comment: "Abbreviated state or province code"
    t.string "country", limit: 32, comment: "Full country name"
    t.string "country_short", limit: 3, comment: "ISO country code (e.g., US)"
    t.string "postal_code", limit: 12, comment: "Postal or ZIP code"
    t.string "postal_code_suffix", limit: 6, comment: "Extra postal code details (e.g., ZIP+4)"
    t.string "post_box", limit: 12, comment: "PO Box number if applicable"
    t.float "latitude", comment: "Latitude coordinate for geolocation"
    t.float "longitude", comment: "Longitude coordinate for geolocation"
    t.string "time_zone", limit: 48, comment: "Time zone of the location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["amigo_id"], name: "index_amigo_locations_on_amigo_id"
  end

  create_table "amigos", force: :cascade do |t|
    t.string "first_name", limit: 50, comment: "First name of the Amigo"
    t.string "last_name", limit: 50, comment: "Last name of the Amigo"
    t.string "user_name", limit: 50, null: false, comment: "Unique username"
    t.string "email", limit: 50, null: false, comment: "Primary email address"
    t.string "secondary_email", limit: 50, comment: "Secondary email address"
    t.string "phone_1", limit: 35, comment: "Primary phone number"
    t.string "phone_2", limit: 35, comment: "Secondary phone number"
    t.string "encrypted_password", default: "", null: false, comment: "Devise-encrypted password"
    t.string "reset_password_token", comment: "Token for resetting password"
    t.datetime "reset_password_sent_at", comment: "Timestamp when password reset token was sent"
    t.datetime "remember_created_at", comment: "Timestamp for remember-me feature"
    t.integer "sign_in_count", default: 0, null: false, comment: "Total sign-in count"
    t.datetime "current_sign_in_at", comment: "Timestamp of current sign-in"
    t.datetime "last_sign_in_at", comment: "Timestamp of last sign-in"
    t.string "current_sign_in_ip", comment: "IP address of current sign-in"
    t.string "last_sign_in_ip", comment: "IP address of last sign-in"
    t.string "confirmation_token", comment: "Token used for email confirmation"
    t.datetime "confirmed_at", comment: "Timestamp when email was confirmed"
    t.datetime "confirmation_sent_at", comment: "Timestamp when confirmation instructions were sent"
    t.string "unconfirmed_email", comment: "Email address waiting for confirmation"
    t.integer "failed_attempts", default: 0, null: false, comment: "Number of failed login attempts"
    t.string "unlock_token", comment: "Token for unlocking account"
    t.datetime "locked_at", comment: "Timestamp when account was locked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "avatar_source", comment: "upload|gravatar|url|default"
    t.string "avatar_remote_url", comment: "When avatar_source = url"
    t.datetime "avatar_synced_at"
    t.integer "role", default: 0, null: false
    t.index "lower((email)::text)", name: "idx_amigos_email_ci", unique: true
    t.index "lower((secondary_email)::text)", name: "idx_amigos_secondary_email_ci", unique: true, where: "((secondary_email IS NOT NULL) AND ((secondary_email)::text <> ''::text))"
    t.index "lower((user_name)::text)", name: "idx_amigos_user_name_ci", unique: true
    t.index ["confirmation_token"], name: "index_amigos_on_confirmation_token", unique: true, where: "(confirmation_token IS NOT NULL)"
    t.index ["phone_1"], name: "idx_amigos_phone_1_unique", unique: true, where: "((phone_1 IS NOT NULL) AND ((phone_1)::text <> ''::text))"
    t.index ["phone_2"], name: "idx_amigos_phone_2_unique", unique: true, where: "((phone_2 IS NOT NULL) AND ((phone_2)::text <> ''::text))"
    t.index ["reset_password_token"], name: "index_amigos_on_reset_password_token", unique: true, where: "(reset_password_token IS NOT NULL)"
    t.index ["role"], name: "index_amigos_on_role"
    t.index ["unlock_token"], name: "index_amigos_on_unlock_token", unique: true, where: "(unlock_token IS NOT NULL)"
  end

  create_table "event_amigo_connectors", force: :cascade do |t|
    t.bigint "amigo_id", null: false, comment: "Reference to the Amigo (user) participating in the event"
    t.bigint "event_id", null: false, comment: "Reference to the associated event"
    t.integer "role", default: 0, null: false, comment: "Role of the Amigo in the event (e.g., participant, assistant_coordinator), stored as enum"
    t.integer "status", default: 0, null: false, comment: "Status of participation (e.g., active/inactive), stored as enum"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["amigo_id"], name: "index_event_amigo_connectors_on_amigo_id"
    t.index ["event_id", "amigo_id"], name: "uniq_event_amigo_per_event", unique: true
    t.index ["event_id"], name: "index_event_amigo_connectors_on_event_id"
    t.index ["event_id"], name: "uniq_lead_coordinator_per_event", unique: true, where: "(role = 2)"
  end

  create_table "event_location_connectors", force: :cascade do |t|
    t.bigint "event_id", null: false, comment: "Reference to the associated event"
    t.bigint "event_location_id", null: false, comment: "Reference to the physical location where the event is held"
    t.integer "status", default: 0, null: false, comment: "Status of the connector (e.g., active/inactive), stored as enum"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_primary", default: false, null: false
    t.index ["event_id", "event_location_id"], name: "uniq_event_location_connector", unique: true
    t.index ["event_id"], name: "index_event_location_connectors_on_event_id"
    t.index ["event_id"], name: "uniq_primary_location_per_event", unique: true, where: "(is_primary = true)"
    t.index ["event_location_id"], name: "index_event_location_connectors_on_event_location_id"
  end

  create_table "event_locations", force: :cascade do |t|
    t.string "business_name", limit: 64, comment: "Name of the venue or business hosting the event"
    t.string "business_phone", limit: 15, comment: "Primary phone number of the business or venue"
    t.string "address", limit: 256, comment: "Full mailing address (may include suite, floor, etc.)"
    t.string "floor", limit: 10, comment: "Floor number if the venue is in a multi-story building"
    t.string "street_number", limit: 32, comment: "Street number of the location"
    t.string "street_name", limit: 96, comment: "Street name of the location"
    t.string "room_no", limit: 32, comment: "Specific room or unit number"
    t.string "apartment_suite_number", limit: 32, comment: "Suite or apartment number if applicable"
    t.string "city_sublocality", limit: 96, comment: "Sub-locality or neighborhood (e.g., district or borough)"
    t.string "city", limit: 64, comment: "City where the event location is situated"
    t.string "state_province_subdivision", limit: 96, comment: "County, prefecture, or similar subdivision"
    t.string "state_province", limit: 32, comment: "State or province name"
    t.string "state_province_short", limit: 8, comment: "Abbreviated state or province code (e.g., CA)"
    t.string "country", limit: 32, comment: "Full country name"
    t.string "country_short", limit: 3, comment: "ISO 3166-1 alpha-2 or alpha-3 country code"
    t.string "postal_code", limit: 12, comment: "ZIP or postal code"
    t.string "postal_code_suffix", limit: 6, comment: "Additional postal code information (e.g., ZIP+4)"
    t.string "post_box", limit: 12, comment: "Post office box number, if applicable"
    t.float "latitude", comment: "Latitude coordinate for geolocation"
    t.float "longitude", comment: "Longitude coordinate for geolocation"
    t.string "time_zone", limit: 48, comment: "Time zone of the event location (e.g., 'Pacific Time (US & Canada)')"
    t.integer "status", default: 0, null: false, comment: "Status of the location (e.g., active/inactive), stored as enum"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "location_type", limit: 32, comment: "Type of venue (cafe, house, etc.)"
    t.string "owner_name", limit: 128, comment: "Owner or primary contact for the venue"
    t.integer "capacity_seated", comment: "Approximate seated capacity"
    t.string "availability_notes", limit: 256, comment: "Free-form notes about when the venue is available"
    t.boolean "has_food", default: false, null: false
    t.boolean "has_drink", default: false, null: false
    t.boolean "has_internet", default: false, null: false
    t.boolean "has_big_screen", default: false, null: false
    t.string "place_id", comment: "Google Places place_id"
    t.integer "capacity", comment: "Approximate seating capacity"
    t.jsonb "services", default: {}, null: false, comment: "JSON hash of boolean flags, e.g. { food: true, internet: true }"
    t.text "location_image_attribution", comment: "Required photo attribution from Google Places"
    t.text "search_criteria", default: [], null: false, array: true
    t.text "search_venue_types", default: [], null: false, array: true
    t.index ["place_id"], name: "index_event_locations_on_place_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "event_name", comment: "Name of the event (e.g., Annual Meetup)"
    t.string "event_type", comment: "Type of event (e.g., Workshop, Seminar, Concert)"
    t.date "event_date", comment: "Date on which the event will be held"
    t.time "event_time", comment: "Time of day the event is scheduled to start"
    t.bigint "lead_coordinator_id", null: false, comment: "Amigo ID of the event's lead coordinator"
    t.integer "status", default: 0, null: false, comment: "Event status (e.g., pendiong, verified, rejected) represented as enum"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "event_speakers_performers", default: [], null: false, array: true
    t.text "description", comment: "Detailed description of the event"
    t.index ["event_speakers_performers"], name: "idx_events_speakers_gin", using: :gin
    t.check_constraint "array_position(event_speakers_performers, ''::text) IS NULL", name: "chk_event_speakers_no_blank"
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.string "jti", null: false, comment: "JWT ID (unique identifier for the token)"
    t.datetime "exp", null: false, comment: "Expiration timestamp of the JWT"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "login_activities", force: :cascade do |t|
    t.string "scope", comment: "Scope of authentication (e.g., :amigo, :admin)"
    t.string "strategy", comment: "Authentication strategy used (e.g., database, OAuth)"
    t.string "identity", comment: "Identifier used for login (e.g., email or username)"
    t.boolean "success", default: false, null: false, comment: "Indicates whether login was successful"
    t.string "failure_reason", comment: "Reason for login failure (e.g., invalid password)"
    t.string "user_type"
    t.bigint "user_id", comment: "Polymorphic association to the authenticated user (e.g., Amigo)"
    t.string "context", comment: "Context or source of login attempt (e.g., web, API)"
    t.string "ip", comment: "IP address of the login request"
    t.text "user_agent", comment: "User-Agent string from the client"
    t.text "referrer", comment: "Referring page or source of the login request"
    t.string "city", comment: "City from which login originated"
    t.string "region", comment: "Region or state of the login source"
    t.string "country", comment: "Country of the login source"
    t.float "latitude", comment: "Geolocation latitude of login source"
    t.float "longitude", comment: "Geolocation longitude of login source"
    t.datetime "created_at", null: false, comment: "Timestamp when login attempt was recorded"
    t.datetime "updated_at", null: false, comment: "Timestamp when the record was last updated"
    t.index ["identity"], name: "index_login_activities_on_identity"
    t.index ["ip"], name: "index_login_activities_on_ip"
    t.index ["user_type", "user_id"], name: "index_login_activities_on_user"
  end

  create_table "models", force: :cascade do |t|
    t.string "email", default: "", null: false, comment: "User's email address (used for authentication)"
    t.string "encrypted_password", default: "", null: false, comment: "Devise-encrypted password hash"
    t.string "reset_password_token", comment: "Token for resetting password"
    t.datetime "reset_password_sent_at", comment: "Timestamp when reset password token was sent"
    t.datetime "remember_created_at", comment: "Timestamp for remember-me session (likely unused in API-only apps)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_models_on_email", unique: true
    t.index ["reset_password_token"], name: "index_models_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "amigo_details", "amigos"
  add_foreign_key "amigo_locations", "amigos"
  add_foreign_key "event_amigo_connectors", "amigos"
  add_foreign_key "event_amigo_connectors", "events"
  add_foreign_key "event_location_connectors", "event_locations"
  add_foreign_key "event_location_connectors", "events"
  add_foreign_key "events", "amigos", column: "lead_coordinator_id"
end
