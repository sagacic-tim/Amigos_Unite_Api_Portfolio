# spec/models/amigo_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Amigo, type: :model do
  it "has a valid factory" do
    amigo = build(:amigo)
    expect(amigo).to be_valid
  end

  it "requires first_name and last_name" do
    amigo = build(:amigo, first_name: nil, last_name: nil)
    expect(amigo).not_to be_valid
    expect(amigo.errors[:first_name]).to be_present
    expect(amigo.errors[:last_name]).to be_present
  end

  it "requires user_name and enforces format" do
    bad = build(:amigo, user_name: "bad name!")
    expect(bad).not_to be_valid
    expect(bad.errors[:user_name]).to be_present
  end

  it "enforces case-insensitive uniqueness of user_name" do
    create(:amigo, user_name: "DuplicateName")
    dup = build(:amigo, user_name: "duplicatename")

    expect(dup).not_to be_valid
    expect(dup.errors[:user_name]).to include("has already been taken")
  end

  it "normalizes identifiers (email downcase/strip)" do
    amigo = create(:amigo, email: "  SOMEONE@Example.COM  ")
    expect(amigo.reload.email).to eq("someone@example.com")
  end

  describe ".find_for_database_authentication" do
    it "finds by user_name" do
      amigo = create(:amigo, user_name: "login_me")
      found = described_class.find_for_database_authentication(login_attribute: "login_me")
      expect(found&.id).to eq(amigo.id)
    end

    it "finds by email (case-insensitive)" do
      amigo = create(:amigo, email: "x@example.com")
      found = described_class.find_for_database_authentication(login_attribute: "X@EXAMPLE.COM")
      expect(found&.id).to eq(amigo.id)
    end

    it "finds by phone (normalized)" do
      amigo = create(:amigo, phone_1: "+14155552671")
      found = described_class.find_for_database_authentication(login_attribute: "+14155552671")
      expect(found&.id).to eq(amigo.id)
    end
  end
end
