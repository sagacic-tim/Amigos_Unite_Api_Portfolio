# app/policies/event_policy.rb

class EventPolicy
  attr_reader :user, :record
  alias_method :amigo, :user

  def initialize(user, record)
    @user   = user
    @record = record
  end

  # --- top-level permissions (public) ---
  def create?  = user.present?
  def show?    = true
  def update?  = admin? || lead? || assistant?
  def destroy? = admin? || lead?

  # Connectors may be managed by admin, lead, or assistant
  def manage_connectors? = admin? || lead? || assistant?

  def manage_locations? = manage_connectors?

  # Roles may be changed only by admin or lead (NO assistant)
  def manage_roles? = admin? || lead?

  private

  def admin?
    amigo&.admin? || false
  end

  def connector
    return nil unless amigo && record
    @connector ||= record.event_amigo_connectors.find_by(amigo_id: amigo.id)
  end

  def lead?
    # Primary: check the connector join table (the authoritative source).
    # Fallback: compare directly against events.lead_coordinator_id so the
    # event creator is never locked out if their connector row is missing
    # (e.g. events created before the connector backfill).
    !!connector&.lead_coordinator? || record&.lead_coordinator_id == amigo&.id
  end

  def assistant?
    !!connector&.assistant_coordinator?
  end
end
