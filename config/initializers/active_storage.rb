# config/initializers/active_storage.rb

# Allow SVGs to be served inline instead of as attachments
Rails.application.config.active_storage.content_types_to_serve_as_binary.delete('image/svg+xml')

# Confirm ActiveStorage is initialized during boot (for debugging/logging)
if defined?(ActiveStorage::Engine)
  Rails.logger.info "[ActiveStorage] Initialized successfully"
end
