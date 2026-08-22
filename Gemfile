source "https://rubygems.org" 
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

gem 'bundler', '~> 2.5', '>= 2.5.17'

# Rails is a web-application framework that includes everything
# needed to create database-backed web applications according
# to the Model-View-Controller (MVC) pattern.
gem 'rails', '~> 7.1', '>= 7.1.3.4'

# ActiveModel::Serializers allows you to generate your JSON in an
# object-oriented and convention-driven manner.
gem 'active_model_serializers', '~> 0.10.14'

gem 'activestorage', '~> 7.1', '>= 7.1.3.4'

# Database
# Pg is the Ruby interface to the PostgreSQL RDBMS. It works
# with PostgreSQL 9.3 and later.
gem 'pg', '~> 1.5', '>= 1.5.7'

# Puma
gem 'puma', '~> 6.4', '>= 6.4.2'

# Systrem gems
  # Shim to load environment variables from .env into ENV in
  # development.
gem 'dotenv-rails', '~> 3.1', '>= 3.1.2', groups: [:development, :test]
  # Rack::Cors provides support for Cross-Origin Resource
  # Sharing (CORS)for Rack compatible web applications.
  # The CORS spec allows web applications to make cross domain
  # AJAX calls without using workarounds such as JSONP.
gem 'rack-cors', '~> 2.0', '>= 2.0.2'
  # A set of responders modules to dry up your Rails 4.2+ app.
gem 'responders', '~> 3.1', '>= 3.1.1'
  # Modern encryption for Ruby and Rails — Works with database fields,
  # files, and strings — Maximizes compatibility with existing code
  # and libraries — Makes migrating existing data and key rotation easy —
  # Has zero dependencies and many integrations
gem 'lockbox', '~> 1.3', '>= 1.3.3'

  # To summarize, we compute a keyed hash of the sensitive data and
  # store it in a column. To query, we apply the keyed hash function
  # to the value we’re searching and then perform a database search.
  # This results in performant queries for exact matches. Efficient
  # LIKE queries are not possible, but you can index expressions.
gem 'blind_index', '~> 2.5'

  # Protect your Rails and Rack apps from bad clients. Rack::Attacklets
  # lets you easily decide when to allow, block and throttle based only
  # properties of the request.
gem 'rack-attack', '~> 6.8'

  # Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '~> 1.18', '>= 1.18.4', require: false

# Devise and related authentication gems
  # Devise is a flexible authentication solution for Rails
  # based on Warden. It:
  # 1. Is Rack based;
  # 2. Is a complete MVC solution based on Rails engines;
  # 3. Allows you to have multiple models signed in at the
  #    same time;
  # 4. Is based on a modularity concept: use only what you
  #    really need.
gem 'devise', '~> 4.9', '>= 4.9.4'
  # devise-jwt is a Devise extension which uses JWT tokens
  # for user authentication. It follows secure by default principle.
gem 'devise-jwt', '~> 0.12.1'
  # using jwt with devise-jwt in a Rails API-only app provides
  # a secure, scalable, and stateless authentication mechanism
  # that leverages Devise's ease of use while also being flexible
  # enough to accommodate various frontend technologies and
  # architectures.
gem 'jwt', '~> 2.8', '>= 2.8.2'
  # OmniAuth is a library that standardizes multi-provider
  # authentication for web applications.
gem 'omniauth', '~> 2.1', '>= 2.1.2'
  # This is the official OmniAuth strategy for authenticating
  # with these services
gem 'omniauth-google-oauth2', '~> 1.1', '>= 1.1.2'
gem 'omniauth-facebook', '~> 10.0'
gem 'omniauth-github', '~> 2.0', '>= 2.0.1'
gem 'omniauth-linkedin-oauth2', '~> 1.0', '>= 1.0.1'
  # This gem provides a mitigation against CVE-2015-9284 by
  # implementing a CSRF token verifier that directly uses
  # ActionController::RequestForgeryProtection code from Rails.
gem 'omniauth-rails_csrf_protection', '~> 1.0', '>= 1.0.2'
  # A LoginActivity record is created every time a user tries
  # to login. You can then use this information to detect
  # suspicious behavior. 
gem 'authtrail', '~> 0.5.0'

# Serialization and JSON DSL
  # Jbuilder gives you a simple DSL for declaring JSON
  # structures that beats manipulating giant hash structures.
gem 'jbuilder', '~> 2.12'
  # A fast JSON:API serializer for Ruby Objects.
gem 'jsonapi-serializer', '~> 2.2'

# Address Validation
# gem 'smartystreets_ruby_sdk', '5.15.2'

# Provides object geocoding (by street or IP address),
# reverse geocoding (coordinates to street address),
# distance queries for ActiveRecord and Mongoid, result
# caching, and more. Designed for Rails but works with
# Sinatra and other Rack frameworks too.
gem 'geocoder', '~> 1.8', '>= 1.8.3'

# The Ruby gem for Google Maps Web Service APIs is a gem for the following Google Maps APIs:
# Google Maps Directions API
# Google Maps Distance Matrix API
# Google Maps Elevation API
# Google Maps Geocoding API
# Google Maps Places API
# Google Maps Time Zone API
# Google Maps Roads API
# Google Maps Routes API
gem 'google_maps_service_ruby', '~> 0.7.0'

# Makes http fun again! Ain't no party like a httparty,
# because a httparty don't stop.
gem 'httparty', '~> 0.22.0'

# Official Anthropic Ruby SDK — used by AgenticLocationSearch to drive
# venue discovery with Claude Haiku tool use.
gem 'anthropic'

# Google Cloud Vision — SafeSearch content moderation for uploaded images
gem 'google-cloud-vision', '~> 2.0', '>= 2.0.3'

# The activerecord-postgis-adapter provides access to features
# of the PostGIS geospatial database from ActiveRecord. It
# extends the standard postgresql adapter to provide support
# for the spatial data types and features added by the PostGIS
# extension. It uses the RGeo library to represent spatial
# data in Ruby.
gem 'activerecord-postgis-adapter', '~> 9.0', '>= 9.0.2'

# Email and Phone Validation
gem 'phonelib', '~> 0.9.1'

# Additional Gems for Country and State Data
gem 'countries', '~> 8.0', require: 'countries/global'
gem 'bigdecimal', '~> 3.1', '>= 3.1.8', require: true

# Sanitize is an allowlist-based HTML and CSS sanitizer. It
# removes all HTML and/or CSS from a string except the
# elements, attributes, and properties you choose to allow.
gem 'sanitize', '~> 7.0'

# Validations for Active Storage
gem 'active_storage_validations', '~> 1.1', '>= 1.1.4'

# Virus scanning for file uploads
gem 'clamby', '~> 1.6', '>= 1.6.11'

# Image processing with support for libvips
gem 'image_processing', '~> 1.13'

# ruby-vips is a binding for the libvips image processing
# library. It is fast and it can process large images withou
# loading the whole image in memory.
gem 'ruby-vips', '~> 2.2', '>= 2.2.2'

# Sidekiq is a full-featured background job framework for Ruby. It aims to
# be simple to integrate with any modern Rails application and much higher
# performance than other existing solutions.
gem 'sidekiq', '~> 8.0', '>= 8.0.7', require: true

# A Ruby client that tries to match Redis' API one-to-one, while still
# providing an idiomatic interface.
gem 'redis', '~> 5.4', '>= 5.4.1'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', '~> 1.9', '>= 1.9.2', platforms: %i[ mri mingw x64_mingw ]

# Faker, a port of Data::Faker from Perl, is used to easily
# generate fake data: names, addresses, phone numbers, etc.
  gem 'faker', '~> 3.4', '>= 3.4.2'

  # In RSpec, tests are not just scripts that verify your applications
  # code. They’re also specifications (or specs, for short): detailedexplanations
  # explanations of how the application is supposed to behave, expressedin
  # in plain English.
  gem 'rspec-rails', '~> 7.1', '>= 7.1.1'

  # foreman - Process manager for applications with multiple components
  gem "foreman", "~> 0.90.0"

end

group :test do
  gem "factory_bot_rails"
end
