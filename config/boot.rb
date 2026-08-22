# Set the path to the Gemfile if not already set
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Load and set up the gems listed in the Gemfile
require "bundler/setup"

# Enable Bootsnap to cache expensive operations and improve boot speed
require "bootsnap/setup"
