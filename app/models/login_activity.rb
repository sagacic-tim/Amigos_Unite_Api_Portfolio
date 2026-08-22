
class LoginActivity < ApplicationRecord
  # Associations
  belongs_to :user, polymorphic: true, optional: true  # use :user to match the migration
  alias_attribute :amigo, :user  # Optional: alias if you still want to reference it as `amigo`

  # Validations (optional, but recommended for meaningful entries)
  validates :identity, presence: true
  validates :ip, presence: true
  validates :user_agent, presence: true

  # Scopes
  scope :successful, -> { where(success: true) }
  scope :failed,     -> { where(success: false) }

  # Instance methods
  def success?
    success
  end
end

