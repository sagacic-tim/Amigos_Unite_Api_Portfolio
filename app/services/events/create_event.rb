# app/services/events/create_event.rb
module Events
  class CreateEvent
    # Public API:
    #   Events::CreateEvent.new.call(
    #     creator: current_amigo,
    #     attrs:   event_params
    #   )
    #
    # This will:
    #   - Create the Event with +creator+ as lead_coordinator
    #   - Create an EventAmigoConnector as lead_coordinator
    #   - Optionally upsert the primary EventLocation if +location+ is provided
    def call(creator:, attrs:)
      raise ArgumentError, "creator must be an Amigo" unless creator.is_a?(Amigo)

      # attrs may be ActionController::Parameters or a plain Hash.
      raw_attrs =
        if attrs.respond_to?(:to_unsafe_h)
          attrs.to_unsafe_h
        else
          attrs.to_h
        end

      raw_attrs = raw_attrs.deep_symbolize_keys

      # Extract nested location attributes, leaving only core event attributes
      location_attrs = raw_attrs.delete(:location)

      Event.transaction do
        # 1) Build and save the event with the lead coordinator set
        event = Event.new(raw_attrs)
        event.lead_coordinator = creator
        event.save!

        # 2) Create the lead coordinator connector
        #    NOTE: we do NOT force a specific status here; we let the
        #    enum / DB default handle it to avoid invalid enum values.
        EventAmigoConnector.create!(
          event: event,
          amigo: creator,
          role:  :lead_coordinator
          # status will use the model/database default
        )

        # 3) Optionally upsert the primary location
        if location_attrs.present?
          Events::UpsertPrimaryLocation.new.call(
            event:     event,
            raw_attrs: location_attrs
          )
        end

        event
      end
    end
  end
end
