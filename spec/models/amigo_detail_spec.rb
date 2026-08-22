# spec/models/amigo_detail_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe AmigoDetail, type: :model do
  it "has a valid factory" do
    expect(build(:amigo_detail)).to be_valid
  end

  it "allows personal_bio to be nil (optional)" do
    detail = build(:amigo_detail, personal_bio: nil)
    expect(detail).to be_valid
  end

  it "allows personal_bio to be blank to clear it" do
    detail = build(:amigo_detail, personal_bio: "")
    expect(detail).to be_valid
  end

  it "rejects personal_bio that sanitizes to empty but was not blank input" do
    detail = build(:amigo_detail, personal_bio: %(<img src=x onerror=alert(1)>))
    expect(detail).not_to be_valid
    expect(detail.errors[:personal_bio]).to include("must contain readable text")
  end

  it "sanitizes unsafe attributes but keeps readable text" do
    detail = build(:amigo_detail, personal_bio: %(<b>Hello</b> <img src=x onerror=alert(1)>))
    expect(detail).to be_valid
    expect(detail.personal_bio).to include("Hello")
    expect(detail.personal_bio).not_to include("onerror")
    expect(detail.personal_bio).not_to include("alert")
  end
end
