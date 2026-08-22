# spec/requests/password_resets_spec.rb
require "rails_helper"

RSpec.describe "Password reset", type: :request do
  let!(:amigo) { create(:amigo, email: "tim@example.com") }

  it "sends reset instructions email" do
    token = SecureRandom.base64(32)
    cookies["CSRF-TOKEN"] = token

    expect {
      post amigo_password_path,
        params: { amigo: { email: amigo.email } },
        as: :json,
        headers: { "X-CSRF-Token" => token }
    }.to have_enqueued_job(ActionMailer::MailDeliveryJob)

    perform_enqueued_jobs

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([amigo.email])
    expect(mail.subject.downcase).to include("reset")
  end
end
