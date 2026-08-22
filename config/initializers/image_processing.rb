# config/initializers/image_processing.rb

# Load and configure the ImageProcessing gem with libvips
Rails.application.reloader.to_prepare do
  require "image_processing/vips"
  unless defined?(VipsLogOnce)
    VipsLogOnce = true
    Rails.logger.info "[ImageProcessing] libvips loaded successfully"
  end
end
