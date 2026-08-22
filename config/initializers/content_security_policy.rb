
Rails.application.configure do
  api_protocol = ENV.fetch("APP_PROTOCOL", "https")
  api_host     = ENV.fetch("APP_HOST", "localhost")
  api_port     = ENV.fetch("APP_PORT", "3001")
  api_origin   = "#{api_protocol}://#{api_host}:#{api_port}"

  config.content_security_policy do |p|
    p.default_src :self
    p.script_src  :self
    p.style_src   :self
    p.img_src     :self, :data
    p.connect_src :self, api_origin
    p.frame_ancestors :none
    p.base_uri :self
  end
  config.content_security_policy_report_only = false
end
