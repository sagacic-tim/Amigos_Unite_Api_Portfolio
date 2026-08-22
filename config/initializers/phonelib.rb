# config/initializers/phonelib.rb

# Default country used when none is specified during parsing
Phonelib.default_country = 'US'

# Allow flexible parsing — accepts numbers like 911, short codes, etc.
Phonelib.strict_check = false

# Always parse and format numbers to international E.164 standard
# Note: Your own logic must call `Phonelib.parse(...).e164` when storing.
# This doesn't enforce formatting, but encourages consistency.

# Optional: Warn developers if they're using outdated data
# Phonelib.override_phone_data = true  # Use static metadata instead of updating from Google

# You *can* check types (mobile, fixed_line, etc.) during validation later:
# Example (safe to use even if not yet implemented):
#   parsed = Phonelib.parse(number)
#   parsed.valid_type?(:mobile)  # <- returns true/false
