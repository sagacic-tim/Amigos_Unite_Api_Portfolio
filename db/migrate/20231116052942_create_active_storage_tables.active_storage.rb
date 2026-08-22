# This migration comes from active_storage (originally 20170806125915)
class CreateActiveStorageTables < ActiveRecord::Migration[7.1]
  def change
    # Use Active Record's configured type for primary and foreign keys
    primary_key_type, foreign_key_type = primary_and_foreign_key_types

    create_table :active_storage_blobs, id: primary_key_type do |t|
      t.string   :key,          null: false, comment: "Unique key identifier for the blob"
      t.string   :filename,     null: false, comment: "Original filename of the uploaded file"
      t.string   :content_type,               comment: "MIME type of the file (e.g., image/png)"
      t.text     :metadata,                  comment: "Serialized metadata (dimensions, etc.)"
      t.string   :service_name, null: false, comment: "Name of the Active Storage service used"
      t.bigint   :byte_size,    null: false, comment: "Size of the file in bytes"
      t.string   :checksum,                  comment: "Base64-encoded checksum of the file"

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: 6, null: false, comment: "Timestamp when blob was created"
      else
        t.datetime :created_at, null: false, comment: "Timestamp when blob was created"
      end

      t.index [:key], unique: true
    end

    create_table :active_storage_attachments, id: primary_key_type do |t|
      t.string     :name,     null: false, comment: "Name of the attachment (e.g., avatar, image)"
      t.references :record,   null: false, polymorphic: true, index: false, type: foreign_key_type,
                              comment: "Polymorphic association to the attached model (e.g., Amigo)"
      t.references :blob,     null: false, type: foreign_key_type,
                              comment: "Reference to the blob containing actual file data"

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: 6, null: false, comment: "Timestamp when attachment was created"
      else
        t.datetime :created_at, null: false, comment: "Timestamp when attachment was created"
      end

      t.index [:record_type, :record_id, :name, :blob_id], name: :index_active_storage_attachments_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    create_table :active_storage_variant_records, id: primary_key_type do |t|
      t.belongs_to :blob, null: false, index: false, type: foreign_key_type,
                          comment: "Reference to the original blob for which variant is generated"
      t.string :variation_digest, null: false, comment: "Digest of the transformation instructions"

      t.index [:blob_id, :variation_digest], name: :index_active_storage_variant_records_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end
  end

  private

  def primary_and_foreign_key_types
    config = Rails.configuration.generators
    setting = config.options[config.orm][:primary_key_type]
    primary_key_type = setting || :primary_key
    foreign_key_type = setting || :bigint
    [primary_key_type, foreign_key_type]
  end
end
