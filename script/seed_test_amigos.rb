# script/seed_test_amigos.rb
#
# Usage (from Rails root on VPS):
#   rails runner script/seed_test_amigos.rb
#
# Expects:  tmp/test_amigos.csv
# Outputs:  tmp/test_amigo_passwords.txt  (keep this file secure / delete after use)
#
# CSV columns (header row required):
#   first_name, last_name, username, password, email,
#   bio, city_group, location_name, state, latitude, longitude
#
# - password column may be left blank; a 16-char secure password is generated.
# - Accounts are pre-confirmed so no confirmation email is sent.
# - Avatars are NOT attached here; add them via the admin UI after running.

require "csv"
require "securerandom"

CSV_PATH    = Rails.root.join("tmp", "amigos_unite_70_test_accounts.csv")
OUTPUT_PATH = Rails.root.join("tmp", "test_amigo_passwords.txt")

US_STATES = {
  "AL" => "Alabama", "AK" => "Alaska", "AZ" => "Arizona", "AR" => "Arkansas",
  "CA" => "California", "CO" => "Colorado", "CT" => "Connecticut", "DE" => "Delaware",
  "FL" => "Florida", "GA" => "Georgia", "HI" => "Hawaii", "ID" => "Idaho",
  "IL" => "Illinois", "IN" => "Indiana", "IA" => "Iowa", "KS" => "Kansas",
  "KY" => "Kentucky", "LA" => "Louisiana", "ME" => "Maine", "MD" => "Maryland",
  "MA" => "Massachusetts", "MI" => "Michigan", "MN" => "Minnesota", "MS" => "Mississippi",
  "MO" => "Missouri", "MT" => "Montana", "NE" => "Nebraska", "NV" => "Nevada",
  "NH" => "New Hampshire", "NJ" => "New Jersey", "NM" => "New Mexico", "NY" => "New York",
  "NC" => "North Carolina", "ND" => "North Dakota", "OH" => "Ohio", "OK" => "Oklahoma",
  "OR" => "Oregon", "PA" => "Pennsylvania", "RI" => "Rhode Island", "SC" => "South Carolina",
  "SD" => "South Dakota", "TN" => "Tennessee", "TX" => "Texas", "UT" => "Utah",
  "VT" => "Vermont", "VA" => "Virginia", "WA" => "Washington", "WV" => "West Virginia",
  "WI" => "Wisconsin", "WY" => "Wyoming", "DC" => "District of Columbia"
}.freeze

unless File.exist?(CSV_PATH)
  abort "ERROR: #{CSV_PATH} not found. Upload your CSV to the tmp/ directory first."
end

ActionMailer::Base.perform_deliveries = false

created  = 0
failed   = 0
results  = []

puts "\nSeeding test amigos from #{CSV_PATH}…\n\n"

CSV.foreach(CSV_PATH, headers: true, header_converters: :symbol, strip: true) do |row|
  password = row[:password].presence || SecureRandom.alphanumeric(16)
  state_short = row[:state].to_s.strip.upcase

  amigo = Amigo.new(
    first_name:            row[:first_name].to_s.strip,
    last_name:             row[:last_name].to_s.strip,
    user_name:             row[:username].to_s.strip,
    email:                 row[:email].to_s.strip.downcase,
    password:              password,
    password_confirmation: password,
    role:                  :amigo
  )

  amigo.skip_confirmation!

  if amigo.save
    AmigoDetail.create!(
      amigo:        amigo,
      personal_bio: row[:bio].to_s.strip
    )

    AmigoLocation.create!(
      amigo:                amigo,
      address:              row[:location_name].to_s.strip,
      city:                 row[:city_group].to_s.strip,
      state_province_short: state_short,
      state_province:       US_STATES.fetch(state_short, state_short),
      country:              "United States",
      country_short:        "US",
      latitude:             row[:latitude].to_s.strip,
      longitude:            row[:longitude].to_s.strip
    )

    results << { email: amigo.email, username: amigo.user_name, password: password, status: "OK" }
    created += 1
    puts "  ✓  #{amigo.email}  (#{amigo.user_name})"
  else
    errors = amigo.errors.full_messages.join(", ")
    results << { email: row[:email], username: row[:username], password: password, status: "FAILED: #{errors}" }
    failed += 1
    puts "  ✗  #{row[:email]} — #{errors}"
  end
end

File.open(OUTPUT_PATH, "w") do |f|
  f.puts "Test Amigo Credentials — generated #{Time.current}"
  f.puts "Keep this file secure. Delete after distributing or saving elsewhere."
  f.puts "-" * 72
  f.printf "%-32s %-20s %s\n", "Email", "Username", "Password"
  f.puts "-" * 72
  results.each do |r|
    f.printf "%-32s %-20s %s  [%s]\n", r[:email], r[:username], r[:password], r[:status]
  end
end

puts "\n#{"─" * 50}"
puts "  Created : #{created}"
puts "  Failed  : #{failed}"
puts "  Total   : #{created + failed}"
puts "\n  Passwords written to #{OUTPUT_PATH}"
puts "  Delete that file once you've saved the credentials.\n\n"
