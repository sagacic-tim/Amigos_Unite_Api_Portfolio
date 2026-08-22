# db/seeds.rb
require 'faker'
require 'json'
require 'marcel'
require 'securerandom'

Faker::UniqueGenerator.clear

residential_address_pool = JSON.parse(File.read('db/random_residential_addresses.json')).shuffle
business_address_pool     = JSON.parse(File.read('db/random_business_addresses.json')).shuffle

avatars_glob  = Rails.root.join('lib', 'seeds', 'avatars', 'images', '*.{png,jpg,jpeg,svg}')
avatar_files  = Dir[avatars_glob.to_s].shuffle

password_file = File.open('tmp/dev_user_passwords.txt', 'w')

# helpers
def make_username
  base = Faker::Internet.unique.username(specifier: 5..12)
  base = base.gsub(/[^a-zA-Z0-9_]/, '_')
  base = "user_#{SecureRandom.hex(2)}" if base.blank?
  base
end

def make_phone(existing)
  # Simple E.164-looking US-like number; good enough for seed uniqueness
  loop do
    num = "+1#{rand(200_000_0000..989_999_9999)}"
    return num unless existing.include?(num)
  end
end

created = []

10.times do |i|
  begin
    password     = Faker::Internet.password(min_length: 12, max_length: 20)
    email        = Faker::Internet.unique.email
    secondary    = Faker::Internet.unique.email
    user_name    = make_username

    # keep phones unique within this run to avoid hitting your unique index
    @phones ||= Set.new
    phone1     = make_phone(@phones); @phones << phone1
    phone2     = make_phone(@phones); @phones << phone2

    amigo = Amigo.create!(
      first_name:           Faker::Name.first_name,
      last_name:            Faker::Name.last_name,
      user_name:            user_name,
      email:                email,
      secondary_email:      secondary,
      phone_1:              phone1,
      phone_2:              phone2,
      password:             password,
      password_confirmation: password,
      confirmed_at:         Time.current
    )

    password_file.puts("Amigo #{i + 1}: Username: #{amigo.user_name}, Email: #{amigo.email}, Password: #{password}")

    if (file = avatar_files.pop) && File.exist?(file)
      amigo.avatar.attach(
        io:           File.open(file),
        filename:     File.basename(file),
        content_type: Marcel::MimeType.for(Pathname.new(file))
      )
    end

    # amigo details
    AmigoDetail.create!(
      amigo:                 amigo,
      member_in_good_standing: [true, false].sample,
      available_to_host:       [true, false].sample,
      willing_to_help:         [true, false].sample,
      willing_to_donate:       [true, false].sample,
      personal_bio:            Faker::Lorem.paragraph(sentence_count: 2),
      date_of_birth:           Faker::Date.birthday(min_age: 18, max_age: 100)
    )

    # amigo location
    if (addr = residential_address_pool.pop)
      AmigoLocation.create!(
        amigo:          amigo,
        street_number:  addr['street_number'],
        street_name:    addr['street_name'],
        city:           addr['city'],
        state_province: addr['state_province'],
        country:        addr['country'],
        postal_code:    addr['postal_code']
      )
    end

    created << amigo.id
  rescue => e
    puts "❌ Failed to create Amigo #{i + 1}: #{e.message}"
  end
end

password_file.close

# Bail on events if we have no amigos (prevents “lead coordinator must exist”)
if created.any?
  5.times do |i|
    begin
      lead  = Amigo.where(id: created).order(Arel.sql('RANDOM()')).first
      event = Event.create!(
        event_name:      Faker::Lorem.sentence(word_count: 3),
        event_type:      %w[Conference Seminar Workshop Concert Festival].sample,
        event_date:      Faker::Date.forward(days: 365),
        event_time:      Faker::Time.forward(days: 365, period: :evening),
        lead_coordinator: lead
      )

      if (addr = business_address_pool.pop)
        location = EventLocation.create!(
          business_name:  addr['business_name'],
          street_number:  addr['street_number'],
          street_name:    addr['street_name'],
          city:           addr['city'],
          state_province: addr['state_province'],
          country:        addr['country'],
          postal_code:    addr['postal_code']
        )
        EventLocationConnector.create!(event: event, event_location: location)
      end

      participants = Amigo.where.not(id: lead.id).sample(rand(3..10))
      assistants   = participants.sample(rand(0..[3, participants.size].min))

      participants.each do |p|
        role = assistants.include?(p) ? 'assistant_coordinator' : 'participant'
        EventAmigoConnector.find_or_create_by!(event: event, amigo: p, role: role)
      end
    rescue => e
      puts "❌ Failed to create Event #{i + 1}: #{e.message}"
    end
  end
end

puts "✅ Seeding complete!"
puts "#{Amigo.count} amigos"
puts "#{AmigoLocation.count} amigo locations"
puts "#{AmigoDetail.count} amigo details"
puts "#{Event.count} events"
puts "#{EventLocation.count} event locations"
puts "#{EventAmigoConnector.count} event participants"
puts "#{EventLocationConnector.count} event location connectors"
