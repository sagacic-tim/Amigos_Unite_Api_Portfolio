# app/models/event_amigo_connector.rb
class EventAmigoConnector < ApplicationRecord
  belongs_to :amigo
  belongs_to :event

  enum role: {
    participant: 0,
    assistant_coordinator: 1,
    lead_coordinator: 2
  }

  enum status: {
    pending: 0,
    confirmed: 1,
    active: 2,
    declined: 3
  }, _prefix: true

  # Validations
  validates :amigo, :event, :role, :status, presence: true
  validates :amigo_id, uniqueness: { scope: :event_id, message: "is already assigned to this event" }
  validate :single_lead_coordinator, if: :lead_coordinator?

  # Scopes
  scope :coordinators, -> { where(role: [:lead_coordinator, :assistant_coordinator]) }
  scope :active, -> { status_confirmed }

  # Callbacks
  before_validation :set_default_status, on: :create

  # Instance Methods
  def coordinator?
    assistant_coordinator? || lead_coordinator?
  end

  private

  def set_default_status
    self.status ||= :pending
  end

  # Ensure only one lead per event
  def single_lead_coordinator
    return unless lead_coordinator?
    exists = EventAmigoConnector
               .where(event_id: event_id, role: :lead_coordinator)
               .where.not(id: id)
               .exists?
    errors.add(:role, "This event already has a lead coordinator") if exists
  end
end
