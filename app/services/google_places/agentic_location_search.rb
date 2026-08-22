# app/services/google_places/agentic_location_search.rb
#
# Agentic venue search powered by Claude Haiku tool use.
#
# Instead of Rails deciding which categories to search and how many results to
# collect, Claude drives the entire process autonomously:
#
#   1. Claude receives the organizer's free-text criteria and the event location.
#   2. Claude decides what to search for and calls search_venues with its own
#      keywords — as many times as it deems necessary (up to MAX_TURNS safety cap).
#   3. If Claude wants more detail on a specific result it calls get_venue_details.
#   4. When satisfied, Claude returns a curated JSON array of venues with a short
#      reason per venue explaining why it matched the criteria.
#
# This approach handles vague or subjective criteria ("cool vibes", "artsy",
# "good for a corporate mixer") far better than keyword pre-matching because
# Claude interprets the intent and picks search terms itself.
#
module GooglePlaces
  class AgenticLocationSearch
    CLAUDE_MODEL  = "claude-haiku-4-5-20251001".freeze
    MAX_RESULTS   = 20
    MAX_TURNS     = 8      # safety cap on agentic iterations
    RADIUS_METRES = 8_047  # 5 miles — hard cap enforced on every returned venue

    # If the eligible-venue pool is still this thin after a search_venues call,
    # widen the acceptance radius by +3 miles for subsequent calls rather than
    # leaving the organizer with only 1-2 options.
    RADIUS_EXPANSION_METRES = 4_828  # +3 miles
    MIN_ELIGIBLE_VENUES     = 4

    # Venue types that are almost never appropriate for a social event.
    # Used as a Ruby-level safety net after Claude returns its list.
    INELIGIBLE_TYPES = %w[
      library school university hospital doctor dentist pharmacy
      local_government_office city_hall courthouse police fire_station
      post_office bank atm finance accounting insurance_agency
      real_estate_agency lawyer car_dealer car_repair gas_station
      parking storage cemetery funeral_home
    ].freeze

    # Types that indicate a venue IS social — presence of any of these
    # overrides an ineligible type (e.g. a university bar is fine).
    SOCIAL_TYPES = %w[
      cafe bar restaurant night_club food bakery lodging
      museum art_gallery stadium amusement_park bowling_alley
      casino movie_theater spa beauty_salon tourist_attraction park
      book_store meal_delivery meal_takeaway
    ].freeze

    # ── Tool definitions exposed to Claude ───────────────────────────────────

    TOOL_DEFINITIONS = [
      {
        name: "search_venues",
        description:
          "Search for venues near the event location using Google Places Text Search. " \
          "Write the query as a natural-language description of the ideal venue — include " \
          "the atmosphere, amenities, and any other criteria. Google will match semantically. " \
          "Returns up to 10 results with place_id, name, address, rating, and venue types. " \
          "Call this multiple times with different query angles to broaden your search.",
        input_schema: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description:
                "Full descriptive query for the type of venue, written like a sentence. " \
                "Embed ALL relevant criteria directly into the query. Examples: " \
                "'jazz blues cafe with indoor seating', " \
                "'soulful coffee lounge with live music', " \
                "'rhythm and blues bar with coffee and indoor seating', " \
                "'cozy cafe with R&B music atmosphere'. " \
                "The more specific the query, the more relevant the results."
            },
            venue_type: {
              type: "string",
              description:
                "Optional Google Places type to anchor results to a specific category. " \
                "Use when you want only one kind of venue: cafe, bar, restaurant, " \
                "night_club, museum, book_store. Omit to search across all types."
            },
            max_results: {
              type: "integer",
              description: "Number of results to return (1–10). Defaults to 8."
            }
          },
          required: ["query"]
        }
      },
      {
        name: "get_venue_details",
        description:
          "Fetch detailed address information for a specific venue by its place_id. " \
          "Use this when you need to confirm a venue's exact street address, " \
          "neighbourhood, or postal code before deciding to include it.",
        input_schema: {
          type: "object",
          properties: {
            place_id: {
              type: "string",
              description: "The Google Places place_id, as returned by search_venues."
            }
          },
          required: ["place_id"]
        }
      }
    ].freeze

    # ── Entry point ───────────────────────────────────────────────────────────

    def self.call(lat:, lng:, city:, state_province:, criteria:, api_key:)
      new(
        lat: lat, lng: lng, city: city, state_province: state_province,
        criteria: criteria, api_key: api_key
      ).call
    end

    def initialize(lat:, lng:, city:, state_province:, criteria:, api_key:)
      @lat              = lat
      @lng              = lng
      @city             = city.to_s.strip
      @state_province   = state_province.to_s.strip
      @criteria         = Array(criteria).map(&:to_s).reject(&:blank?)
      @api_key          = api_key
      # Stores place_id → types[] from actual Google responses so post_filter
      # uses real data rather than whatever Claude writes into its output JSON.
      @place_type_cache = {}
      # Stores place_id → { lat:, lng: } so coordinates can be merged into the
      # final result — Claude's output JSON never includes lat/lng.
      @coords_cache     = {}
      # Radius actually enforced on incoming results; starts at RADIUS_METRES
      # and may widen — see maybe_expand_radius!.
      @effective_radius_metres = RADIUS_METRES
    end

    def call
      run_agentic_loop
    rescue Anthropic::Errors::APIStatusError => e
      if billing_error?(e)
        Rails.logger.error(
          "[AgenticLocationSearch] ANTHROPIC_BILLING_ERROR (status=#{e.status}): #{e.message} — " \
          "check credit balance / auto-reload at console.anthropic.com"
        )
      else
        Rails.logger.error("[AgenticLocationSearch] Anthropic API error (status=#{e.status}): #{e.message}")
      end
      []
    rescue Anthropic::Errors::Error => e
      Rails.logger.error("[AgenticLocationSearch] Anthropic error: #{e.message}")
      []
    rescue StandardError => e
      Rails.logger.error("[AgenticLocationSearch] Unexpected error: #{e.class}: #{e.message}")
      []
    end

    private

    # Anthropic returns a 400 invalid_request_error with a "credit balance"
    # message when the account has run out of API credits — same status code
    # as an ordinary bad request, so we key off the message text to tell them
    # apart and make the low-balance case greppable in logs.
    def billing_error?(error)
      error.status.to_i == 400 && error.message.to_s.match?(/credit balance|insufficient.*credit|billing/i)
    end

    # ── Agentic loop ──────────────────────────────────────────────────────────

    def run_agentic_loop
      messages = [{ role: "user", content: "Please find venues that match my criteria." }]
      turns    = 0

      loop do
        turns += 1
        if turns > MAX_TURNS
          Rails.logger.warn("[AgenticLocationSearch] Safety limit reached after #{MAX_TURNS} turns")
          break
        end

        response = anthropic_client.messages.create(
          model:      CLAUDE_MODEL,
          max_tokens: 4096,
          system:     build_system_prompt,
          tools:      TOOL_DEFINITIONS,
          messages:   messages
        )

        # Official SDK returns SDK objects — serialize to plain hashes for messages history.
        content_blocks = response.content
        messages << { role: "assistant", content: serialize_content(content_blocks) }

        # Official SDK may return stop_reason as a symbol (:tool_use) rather than
        # a string ("tool_use"), so normalise before comparing.
        case response.stop_reason.to_s
        when "end_turn"
          # Ineligible types are already stripped by the pre-filter in dispatch_tool;
          # post_filter_venues applies a final Ruby check using cached Google types.
          venues = post_filter_venues(extract_final_venues(content_blocks))
          Rails.logger.info("[AgenticLocationSearch] Returning #{venues.size} venues after #{turns} turn(s)")
          return venues

        when "tool_use"
          tool_results = execute_tool_calls(content_blocks)
          messages << { role: "user", content: tool_results }

        else
          Rails.logger.warn("[AgenticLocationSearch] Unexpected stop_reason: #{response.stop_reason}")
          break
        end
      end

      []
    end

    # ── System prompt ─────────────────────────────────────────────────────────

    def build_system_prompt
      criteria_text = @criteria.each_with_index.map { |c, i| "#{i + 1}. #{c}" }.join("\n")

      criteria_count = @criteria.size

      <<~SYSTEM
        You are a venue scout for social events. Your job is to find and RANK venues
        against the organizer's criteria. You MUST always return a JSON result —
        never refuse, never explain why you can't return results.

        Search area : #{@city}, #{@state_province}
        Coordinates : #{@lat}, #{@lng}
        Radius      : 5 miles (8 047 metres)
        Total criteria: #{criteria_count}

        Organizer's criteria (numbered for scoring):
        #{criteria_text}

        ── SEARCH PROCESS ──────────────────────────────────────────────────────────
        1. Translate each criterion into search terms. Examples:
             "organic / healthy"    → "organic cafe", "health food cafe", "juice bar"
             "quiet atmosphere"     → "quiet cafe", "independent coffee shop", "study cafe"
             "has internet / wifi"  → independent cafes universally have WiFi; use "cafe wifi"
             "cool vibes / R&B"     → "jazz blues bar", "live music lounge"
             "has coffee"           → "coffee shop", "cafe"
             "indoor seating"       → avoid parks, rooftop-only venues, outdoor markets
        2. Run 3–5 focused searches using venue_type when helpful.
        3. If, after your focused searches, you have fewer than #{MIN_ELIGIBLE_VENUES} total
           eligible venues, run at least one more search with broader, more general terms —
           drop niche descriptors (e.g. "jazz blues cafe" → "cafe", "artsy cocktail lounge" →
           "bar" or "lounge") and omit venue_type so results aren't restricted to one category.
           Prefer ending with more venues at lower criteria-match counts over returning only
           1-2 venues.

        ── SCORING EACH VENUE ──────────────────────────────────────────────────────
        For each venue, count how many criteria it LIKELY satisfies using inference:
        - Google Places does not return WiFi, noise levels, or sourcing data.
          Use venue name and type to infer: a cafe named "Organic Kitchen" likely satisfies
          "organic"; an independent coffee shop almost certainly satisfies "has WiFi";
          a tea house or library-cafe likely satisfies "quiet atmosphere".
        - Assign each venue a criteria_matched count (0–#{criteria_count}).

        ── RANKING ORDER ───────────────────────────────────────────────────────────
        Sort your results in this exact order:
          1st: venues matching ALL #{criteria_count} criteria
          2nd: venues matching #{[criteria_count - 1, 0].max} criteria
          3rd: venues matching #{[criteria_count - 2, 0].max} criteria
          (and so on, down to 1 criterion matched)
        Within each tier, prefer higher-rated venues.
        Include venues even if they only match 1 criterion — partial matches are valuable.

        ── MANDATORY EXCLUSIONS ────────────────────────────────────────────────────
        Never include venues of these types (unless explicitly requested):
          library, school, university, hospital, doctor, dentist,
          government_office, city_hall, courthouse, police, fire_station,
          post_office, bank, atm, accounting, insurance_agency, car_dealer,
          car_repair, gas_station, parking, storage, cemetery, funeral_home.

        ── OUTPUT — MANDATORY ──────────────────────────────────────────────────────
        YOU MUST output ONLY a raw JSON array. No markdown fences. No explanation text.
        No apologies. No preamble. The very first character of your response must be [
        and the very last must be ].

        [
          {
            "place_id": "ChIJ...",
            "name": "Venue Name",
            "formatted_address": "123 Main St, City, ST 00000",
            "rating": 4.3,
            "types": ["cafe", "establishment"],
            "criteria_matched": #{criteria_count},
            "reason": "Criterion 1: likely met because it is a health-food cafe. Criterion 2: likely met — independent cafes almost always offer WiFi. Criterion 3: tea-house setting suggests quiet atmosphere."
          }
        ]
      SYSTEM
    end


    # ── Tool execution ────────────────────────────────────────────────────────

    def execute_tool_calls(content_blocks)
      content_blocks.select { |b| b.type.to_s == "tool_use" }.map do |tool|
        result = dispatch_tool(tool.name, tool.input)
        {
          type:        "tool_result",
          tool_use_id: tool.id,
          content:     result.to_json
        }
      end
    end

    def dispatch_tool(name, input)
      # Official SDK may return input as an SDK-typed object rather than a plain Hash.
      # Normalise to a plain Hash with string keys so bracket access works reliably.
      input = input.to_h.transform_keys(&:to_s)

      case name
      when "search_venues"
        # Accept both 'query' and 'keyword' defensively in case Claude uses either name
        query      = (input["query"].presence || input["keyword"].to_s).strip
        venue_type = input["venue_type"].to_s.presence
        n          = input["max_results"].to_i
        max        = n.between?(1, 10) ? n : 8

        radius = @effective_radius_metres

        Rails.logger.info(
          "[AgenticLocationSearch] search_venues query=#{query.inspect} " \
          "type=#{venue_type.inspect} radius=#{radius}m"
        )

        # ── Step 1: text search (semantic intent matching) ──────────────────
        # Google's Text Search API treats `radius` as a bias, not a hard limit,
        # so it can return results well outside it — the radius check below
        # (Step 3) is what actually enforces the constraint.
        text_results = begin
          places_client.text_search_near(
            query:         query,
            lat:           @lat,
            lng:           @lng,
            radius_metres: radius,
            type:          venue_type,
            max_results:   max
          )
        rescue GooglePlaces::Error => e
          Rails.logger.warn("[AgenticLocationSearch] text_search_near failed: #{e.message}")
          []
        end

        # ── Step 2: nearby search fallback if text search returned too few ──
        # Nearby search is location-constrained and reliably returns results
        # even for smaller markets where text search may find nothing.
        results = if text_results.size >= 3
          text_results
        else
          Rails.logger.info(
            "[AgenticLocationSearch] text_search returned #{text_results.size} result(s) — " \
            "supplementing with nearby_search"
          )
          nearby = begin
            places_client.nearby_search(
              lat:           @lat,
              lng:           @lng,
              radius_metres: radius,
              keyword:       query,
              type:          venue_type,
              max_results:   max
            )
          rescue GooglePlaces::Error => e
            Rails.logger.warn("[AgenticLocationSearch] nearby_search also failed: #{e.message}")
            []
          end

          # Merge text + nearby, dedup by place_id, text results take precedence
          seen = text_results.map { |r| r[:place_id] }.to_set
          text_results + nearby.reject { |r| seen.include?(r[:place_id]) }
        end

        # ── Step 3: pre-filter ineligible types AND out-of-radius results ───
        # before Claude ever sees them.
        before_count = results.size
        eligible     = results.reject do |p|
          ineligible_venue?(p[:types]) || out_of_radius?(p[:lat], p[:lng], radius)
        end

        # Cache real Google types and coordinates keyed by place_id
        eligible.each do |p|
          @place_type_cache[p[:place_id]] = Array(p[:types])
          @coords_cache[p[:place_id]]     = { lat: p[:lat], lng: p[:lng] } if p[:lat] && p[:lng]
        end

        removed = before_count - eligible.size
        Rails.logger.info(
          "[AgenticLocationSearch] search_venues: #{before_count} raw → " \
          "#{eligible.size} eligible (#{removed} removed — ineligible type or outside #{radius}m)"
        ) if removed > 0

        maybe_expand_radius!

        eligible.map do |p|
          {
            place_id:          p[:place_id],
            name:              p[:name],
            formatted_address: p[:formatted_address],
            rating:            p[:rating],
            types:             p[:types]
          }
        end

      when "get_venue_details"
        place_id = input["place_id"].to_s.strip
        places_client.address_for_place(place_id)

      else
        { error: "Unknown tool: #{name}" }
      end

    rescue GooglePlaces::Error => e
      Rails.logger.warn("[AgenticLocationSearch] Tool '#{name}' failed: #{e.message}")
      { error: e.message }
    end

    # ── Response parsing ──────────────────────────────────────────────────────

    def extract_final_venues(content_blocks)
      text_block = content_blocks.find { |b| b.type.to_s == "text" }
      return [] unless text_block

      full_text = text_block.text.to_s

      # Claude sometimes wraps the JSON in a markdown fence or adds a preamble paragraph.
      # Try to extract the JSON array from wherever it appears in the response.
      raw = full_text[/```json\s*(\[.*?\])\s*```/mi, 1] ||   # ```json [...] ```
            full_text[/```\s*(\[.*?\])\s*```/mi, 1]  ||      # ``` [...] ```
            full_text[/(\[.+\])/m, 1]                ||      # bare [...] anywhere
            full_text.strip

      venues = JSON.parse(raw.strip)
      return [] unless venues.is_a?(Array)

      mapped = venues.filter_map do |v|
        next unless v.is_a?(Hash) && v["place_id"].present?
        pid    = v["place_id"].to_s
        coords = @coords_cache[pid] || {}
        {
          place_id:          pid,
          name:              v["name"].to_s,
          formatted_address: v["formatted_address"].to_s,
          lat:               coords[:lat],
          lng:               coords[:lng],
          rating:            v["rating"],
          types:             Array(v["types"]),
          criteria_matched:  v["criteria_matched"].to_i,
          description:       v["reason"].to_s  # map reason → description for frontend compat
        }
      end

      # Sort by criteria_matched desc, then rating desc — server-side safety net
      # in case Claude's ordering drifted from instructions.
      sorted = mapped.sort_by { |v| [-(v[:criteria_matched]), -(v[:rating] || 0)] }
      sorted.first(MAX_RESULTS)

    rescue JSON::ParserError
      Rails.logger.error("[AgenticLocationSearch] Could not parse final JSON: #{raw.inspect}")
      []
    end

    # Ruby-level safety net applied after Claude's verification pass.
    # Uses @place_type_cache (real Google data) rather than whatever types
    # Claude chose to write into its output JSON — so this cannot be fooled
    # by Claude omitting or altering the types field.
    def post_filter_venues(venues)
      venues.reject do |v|
        # Prefer cached types from Google; fall back to Claude's output types.
        types = (@place_type_cache[v[:place_id]] || Array(v[:types]))
                  .map(&:to_s)

        if ineligible_venue?(types)
          Rails.logger.info(
            "[AgenticLocationSearch] Post-filter removed '#{v[:name]}' " \
            "(types: #{types.inspect})"
          )
          true
        else
          false
        end
      end
    end

    # Returns true if a types array belongs to a clearly non-social venue
    # AND has no social type present to redeem it.
    def ineligible_venue?(types)
      t = Array(types).map(&:to_s)
                      .reject { |x| %w[establishment point_of_interest].include?(x) }
      t.any? { |x| INELIGIBLE_TYPES.include?(x) } &&
        t.none? { |x| SOCIAL_TYPES.include?(x) }
    end

    # ── Radius enforcement ────────────────────────────────────────────────────

    EARTH_RADIUS_METRES = 6_371_000

    # True when coordinates are missing or fall outside radius_metres of the
    # event location. This is what actually enforces the distance constraint,
    # since Google's Text Search radius parameter is only a bias.
    def out_of_radius?(lat, lng, radius_metres)
      return true if lat.nil? || lng.nil?

      haversine_distance_metres(@lat, @lng, lat, lng) > radius_metres
    end

    def haversine_distance_metres(lat1, lng1, lat2, lng2)
      to_rad = ->(deg) { deg.to_f * Math::PI / 180 }

      dlat = to_rad.call(lat2 - lat1)
      dlng = to_rad.call(lng2 - lng1)
      a = Math.sin(dlat / 2)**2 +
          Math.cos(to_rad.call(lat1)) * Math.cos(to_rad.call(lat2)) * Math.sin(dlng / 2)**2

      EARTH_RADIUS_METRES * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)))
    end

    # Once the eligible pool is confirmed too thin, widen the acceptance
    # radius for subsequent search_venues calls. Sticky — never shrinks back.
    def maybe_expand_radius!
      return if @effective_radius_metres > RADIUS_METRES
      return if @coords_cache.size >= MIN_ELIGIBLE_VENUES

      @effective_radius_metres = RADIUS_METRES + RADIUS_EXPANSION_METRES
      Rails.logger.info(
        "[AgenticLocationSearch] Only #{@coords_cache.size} eligible venue(s) so far — " \
        "widening radius to #{@effective_radius_metres}m for subsequent searches"
      )
    end

    # ── Helpers ───────────────────────────────────────────────────────────────

    # Serialize official SDK content block objects to plain hashes so they can
    # be included in the messages array for subsequent API turns.
    # Serialize official SDK content block objects to plain hashes so they can
    # be included in the messages array for subsequent API turns.
    # Note: SDK returns block.type as a Symbol (:text, :tool_use), so .to_s is required.
    def serialize_content(content_blocks)
      content_blocks.map do |block|
        case block.type.to_s
        when "text"
          { type: "text", text: block.text }
        when "tool_use"
          { type: "tool_use", id: block.id, name: block.name, input: block.input }
        else
          { type: block.type.to_s }
        end
      end
    end

    def anthropic_client
      @anthropic_client ||= Anthropic::Client.new(api_key: @api_key)
    end

    def places_client
      @places_client ||= GooglePlaces::Client.new
    end
  end
end
