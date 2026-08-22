# spec/models/amigo_location_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe AmigoLocation, type: :model do
  it "has a valid factory" do
    expect(build(:amigo_location)).to be_valid
  end

  it "requires address" do
    loc = build(:amigo_location, address: nil)
    expect(loc).not_to be_valid
    expect(loc.errors[:address]).to include("can't be blank")
  end

  it "validates latitude/longitude ranges when provided" do
    loc = build(:amigo_location, latitude: 200, longitude: 0)
    expect(loc).not_to be_valid
    expect(loc.errors[:latitude]).to be_present

    loc = build(:amigo_location, latitude: 0, longitude: 200)
    expect(loc).not_to be_valid
    expect(loc.errors[:longitude]).to be_present
  end
end
