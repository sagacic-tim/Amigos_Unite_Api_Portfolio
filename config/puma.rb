# config/puma.rb
require "etc"

env = ENV.fetch("RAILS_ENV", "development")
environment env
clear_binds!
warn "[puma.rb] ENV_PORT=#{ENV['PORT'].inspect} argv=#{ARGV.inspect}"

min_threads = ENV.fetch("RAILS_MIN_THREADS", "1").to_i
max_threads = ENV.fetch("RAILS_MAX_THREADS", "5").to_i
threads min_threads, max_threads

port_number = ENV.fetch("PORT", "3001").to_i
warn "[puma.rb] computed port_number=#{port_number}"
app_root = File.expand_path("..", __dir__)

use_dev_ssl = (env == "development" && ENV["PUMA_DEV_SSL"] == "true")

if use_dev_ssl
  worker_timeout 3600

  cert_path = File.join(app_root, "localhost.pem")
  key_path  = File.join(app_root, "localhost-key.pem")
  raise "[puma] Missing cert/key" unless File.exist?(cert_path) && File.exist?(key_path)

  ssl_bind "0.0.0.0", port_number,
           cert: cert_path,
           key: key_path,
           verify_mode: "none"
else
  bind "tcp://0.0.0.0:#{port_number}"
end

plugin :tmp_restart
