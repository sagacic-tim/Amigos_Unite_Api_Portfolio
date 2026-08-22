# app/models/event_location_connector.rb
class EventLocationConnector < ApplicationRecord
  belongs_to :event
  belongs_to :event_location

  enum status: {
    pending: 0,
    confirmed: 1,
    active: 2,
    rejected: 3
  }

  validates :event_location_id, uniqueness: { scope: :event_id }
  validates :status, presence: true
  validates :event_id,
    uniqueness: {
      conditions: -> { where(is_primary: true) },
      message: "already has a primary location"
    },
    if: :is_primary?

  # Default status must be applied AFTER factories/params assign attributes (including nil)
  before_validation :set_default_status, on: :create

  private

  def set_default_status
    self.status = :pending if status.blank?
  end
end
