# app/serializers/event_serializer.rb
class EventSerializer < ActiveModel::Serializer
  attributes :id,
             :event_name,
             :event_type,
             :event_speakers_performers,
             :event_date,
             :event_time,
             :description,
             :status,
             :status_label,
             :lead_coordinator_id,
             :formatted_event_date,
             :formatted_event_time,
             :created_at,
             :updated_at

  # Let AMS infer AmigoSerializer from the Amigo model
  belongs_to :lead_coordinator

  # Let AMS infer EventLocationSerializer from the EventLocation model
  has_one :primary_event_location

  # Ensure we always return an array (never nil) to the FE
  def event_speakers_performers
    object.event_speakers_performers || []
  end

  # Keep the raw enum in :status, but provide a human-friendly string
  def status_label
    object.status.to_s  # e.g., "planning", "active", "completed", "canceled"
  end

  def formatted_event_date
    value = object.event_date
    return nil if value.blank?

    if value.respond_to?(:strftime)
      value.strftime("%Y-%m-%d")
    else
      Date.parse(value.to_s).strftime("%Y-%m-%d")
    end
  rescue ArgumentError, NoMethodError
    value.to_s
  end

  def formatted_event_time
    value = object.event_time
    return nil if value.blank?

    if value.respond_to?(:strftime)
      value.strftime("%H:%M:%S")
    else
      Time.parse(value.to_s).strftime("%H:%M:%S")
    end
  rescue ArgumentError, NoMethodError
    value.to_s
  end
end
