# app/services/google_places/ai_location_suggestions.rb
#
# Venue search coordinator — three paths:
#
#   1. NAMED VENUE  — User typed a specific business name (e.g. "Starbucks").
#                     Search Google Places by name; skip Claude entirely.
#
#   2. AGENTIC      — User supplied free-text criteria (e.g. "cool vibes",
#                     "good for a corporate mixer"). Delegates to
#                     AgenticLocationSearch, which gives Claude Haiku two
#                     Google Places tools and lets it drive the search end-to-end:
#                     choosing keywords, deciding how many searches to run, and
#                     returning a curated list with per-venue reasons.
#
#   3. CATEGORY     — No criteria given. Collect candidates from Google Places
#                     using the user's selected venue categories (or sensible
#                     defaults), sort by rating, and return. No Claude call.
#
module GooglePlaces
  class AiLocationSuggestions
    RADIUS_METRES      = 8_047    # 5 miles
    RESULTS_PER_BUCKET = 8        # fetched per category; pool = up to 3 × 8 = 24
    MAX_RESULTS        = 20       # hard cap on pins returned to the map
    MAX_VENUE_TYPES    = 3        # user may select at most 3 categories

    # -------------------------------------------------------------------------
    # 20 curated venue categories.
    # type:    Google Places type passed to nearbysearch (nil = keyword-only)
    # keyword: focused search term that keeps results on-category
    # outdoor: true → excluded for evening events (before 06:00 or after 18:00)
    # -------------------------------------------------------------------------
    VENUE_CATEGORIES = {
      # ── Food & Drink ────────────────────────────────────────────────────────
      "coffee_shop"      => { type: "cafe",                    keyword: "independent coffee shop cafe",                    outdoor: false },
      "juice_bar"        => { type: "cafe",                    keyword: "juice bar smoothie healthy organic cafe",          outdoor: false },
      "restaurant"       => { type: "restaurant",              keyword: "restaurant dining",                                outdoor: false },
      "bar_pub"          => { type: "bar",                     keyword: "bar pub tavern lounge",                            outdoor: false },
      "bookstore_cafe"   => { type: "book_store",              keyword: "bookstore cafe reading lounge",                    outdoor: false },
      "brewery"          => { type: "bar",                     keyword: "craft brewery taproom microbrewery",               outdoor: false },
      # ── Work & Study ────────────────────────────────────────────────────────
      "coworking"        => { type: nil,                       keyword: "coworking space day office",                       outdoor: false },
      "library"          => { type: "library",                 keyword: "library",                                          outdoor: false },
      "university"       => { type: "university",              keyword: "university campus",                                outdoor: false },
      "hotel_meeting"    => { type: "lodging",                 keyword: "hotel meeting room conference",                    outdoor: false },
      # ── Community & Culture ─────────────────────────────────────────────────
      "community_center" => { type: "local_government_office", keyword: "community center civic hall",                      outdoor: false },
      "museum_gallery"   => { type: "museum",                  keyword: "museum art gallery",                               outdoor: false },
      "theater"          => { type: nil,                       keyword: "theater auditorium concert hall performance",      outdoor: false },
      "historical_site"  => { type: "tourist_attraction",      keyword: "historical site landmark",                         outdoor: true  },
      # ── Outdoor ─────────────────────────────────────────────────────────────
      "park_garden"      => { type: "park",                    keyword: "park garden outdoor",                              outdoor: true  },
      "rooftop"          => { type: nil,                       keyword: "rooftop bar terrace outdoor venue",                outdoor: true  },
      # ── Events & Nightlife ──────────────────────────────────────────────────
      "event_venue"      => { type: nil,                       keyword: "banquet hall event venue private hire",            outdoor: false },
      "club_lounge"      => { type: "night_club",              keyword: "club lounge evening entertainment",                outdoor: false },
      "religious_venue"  => { type: "church",                  keyword: "church temple mosque synagogue parish",            outdoor: false },
      "tea_house"        => { type: "cafe",                    keyword: "tea house tea room lounge",                        outdoor: false },
    }.freeze

    # -------------------------------------------------------------------------
    def self.call(city:, state_province:, country:, criteria:, venue_types: [],
                  venue_name: nil, lat: nil, lng: nil, event_start_time: nil)
      new(
        city: city, state_province: state_province, country: country,
        venue_name: venue_name, criteria: criteria, venue_types: venue_types,
        lat: lat, lng: lng, event_start_time: event_start_time
      ).call
    end

    def initialize(city:, state_province:, country:, criteria:, venue_types: [],
                   venue_name: nil, lat: nil, lng: nil, event_start_time: nil)
      @city             = city.to_s.strip
      @state_province   = state_province.to_s.strip
      @country          = country.to_s.strip
      @venue_name       = venue_name.to_s.strip
      @criteria         = Array(criteria).map(&:to_s).reject(&:blank?)
      @venue_types      = Array(venue_types).map(&:to_s).reject(&:blank?)
      @lat              = lat
      @lng              = lng
      @event_start_time = event_start_time.to_s.strip
    end

    def call
      resolve_coordinates!

      if @venue_name.present?
        # ── Path 1: Named-venue ───────────────────────────────────────────────
        # User specified an exact business name — keyword search is precise
        # enough; skip Claude entirely.
        raw       = collect_by_name
        described = raw.map { |p| p.merge(description: build_synthetic_description(p)) }
        described.first(MAX_RESULTS)

      elsif @criteria.any?
        # ── Path 2: Agentic ───────────────────────────────────────────────────
        # Free-text criteria present — let Claude Haiku drive the search.
        # If agentic returns nothing we return [] rather than falling back to
        # category search, which has no criteria awareness and would return
        # completely irrelevant venues (libraries, city halls, etc.).
        agentic_search

      else
        # ── Path 3: Category ─────────────────────────────────────────────────
        # No criteria — collect by venue category, sort by rating, no Claude.
        category_search
      end
    end

    private

    # ── Path 2: Agentic search ────────────────────────────────────────────────

    def agentic_search
      api_key = ENV["ANTHROPIC_API_KEY"].presence ||
                Rails.application.credentials.dig(:anthropic, :api_key).to_s

      unless api_key.present?
        Rails.logger.error("[AiLocationSuggestions] Anthropic API key missing — cannot run agentic search")
        return []
      end

      AgenticLocationSearch.call(
        lat:            @lat,
        lng:            @lng,
        city:           @city,
        state_province: @state_province,
        criteria:       @criteria,
        api_key:        api_key
      )
    end

    # ── Path 3: Category search ───────────────────────────────────────────────

    def category_search
      buckets   = user_selected_buckets? ? validated_venue_types : default_buckets
      raw       = collect_candidates(buckets)
      described = raw.map { |p| p.merge(description: build_synthetic_description(p)) }
      described.first(MAX_RESULTS)
    end

    # ── Geocode ───────────────────────────────────────────────────────────────

    def resolve_coordinates!
      return if @lat.present? && @lng.present?

      address = [@city, @state_province, @country].reject(&:blank?).join(", ")
      raise GooglePlaces::Error.new("City/location is required", http_code: 422) if address.blank?

      coords = client.geocode(address)
      raise GooglePlaces::Error.new("Could not geocode '#{address}'", http_code: 422) unless coords

      @lat = coords[:lat]
      @lng = coords[:lng]
    end

    # ── Step 1: Google Places search ─────────────────────────────────────────

    def collect_candidates(bucket_keys)
      seen_ids = {}
      results  = []

      bucket_keys.each do |key|
        cat = VENUE_CATEGORIES[key]
        next unless cat

        places = client.nearby_search(
          lat:           @lat,
          lng:           @lng,
          radius_metres: RADIUS_METRES,
          keyword:       cat[:keyword],
          type:          cat[:type],
          max_results:   RESULTS_PER_BUCKET
        )

        places.each do |place|
          pid = place[:place_id]
          next if seen_ids[pid]
          seen_ids[pid] = true
          results << place
        end
      rescue GooglePlaces::Error => e
        Rails.logger.warn("[AiLocationSuggestions] Bucket '#{key}' failed: #{e.message}")
      end

      # Sort by rating descending (nils last)
      results.sort_by { |p| [p[:rating] ? 0 : 1, -(p[:rating] || 0)] }
    end

    # ── Step 1 (named-venue path): search by venue name ──────────────────────
    #
    # When the user supplies a specific venue name (e.g. "Starbucks"), use it
    # as the primary keyword. If the user also selected venue types, search
    # within each of those types to keep results relevant; otherwise do a
    # single open search with the name alone.

    def collect_by_name
      if user_selected_buckets?
        # Search within each selected venue type, prepending the venue name to
        # the category keyword so Google biases towards matching chains/brands.
        seen_ids = {}
        results  = []

        validated_venue_types.each do |key|
          cat     = VENUE_CATEGORIES[key]
          next unless cat

          keyword = [@venue_name, cat[:keyword]].join(" ")

          places = client.nearby_search(
            lat:           @lat,
            lng:           @lng,
            radius_metres: RADIUS_METRES,
            keyword:       keyword,
            type:          cat[:type],
            max_results:   RESULTS_PER_BUCKET
          )

          places.each do |place|
            pid = place[:place_id]
            next if seen_ids[pid]
            seen_ids[pid] = true
            results << place
          end
        rescue GooglePlaces::Error => e
          Rails.logger.warn("[AiLocationSuggestions#collect_by_name] Bucket '#{key}' failed: #{e.message}")
        end

        results.sort_by { |p| [p[:rating] ? 0 : 1, -(p[:rating] || 0)] }
      else
        # No venue type selected — do a single open keyword search.
        places = client.nearby_search(
          lat:           @lat,
          lng:           @lng,
          radius_metres: RADIUS_METRES,
          keyword:       @venue_name,
          type:          nil,
          max_results:   MAX_RESULTS
        )
        places.uniq { |p| p[:place_id] }
              .sort_by { |p| [p[:rating] ? 0 : 1, -(p[:rating] || 0)] }
      end
    end

    # ── Step 1: build synthetic description ──────────────────────────────────

    def build_synthetic_description(place)
      parts = []

      # Readable type labels — strip generic noise types
      noise = %w[establishment point_of_interest food premise]
      types = Array(place[:types]).reject { |t| noise.include?(t) }.first(3)
      parts << types.map { |t| t.tr("_", " ") }.join(", ") if types.any?

      parts << "rated #{place[:rating]}/5" if place[:rating].present?
      parts << place[:formatted_address]   if place[:formatted_address].present?

      parts.join(" — ")
    end

    # ── Helpers ───────────────────────────────────────────────────────────────

    def user_selected_buckets?
      @venue_types.any?
    end

    def validated_venue_types
      available = available_categories
      valid = @venue_types.select { |k| available.key?(k) }.first(MAX_VENUE_TYPES)
      valid.any? ? valid : default_buckets
    end

    def available_categories
      VENUE_CATEGORIES.reject { |_, cat| cat[:outdoor] && !daytime_event? }
    end

    def daytime_event?
      return false if @event_start_time.blank?
      hour = @event_start_time.split(":").first.to_i
      hour >= 6 && hour < 18
    end

    def default_buckets
      daytime_event? ? %w[coffee_shop library community_center] : %w[coffee_shop restaurant community_center]
    end

    def client
      @client ||= GooglePlaces::Client.new
    end
  end
end
