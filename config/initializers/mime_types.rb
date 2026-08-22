# config/initializers/mime_types.rb

# Default Rails types
Mime::Type.register "image/svg+xml", :svg        # For serving inline SVG assets
Mime::Type.register "application/json", :json    # API JSON requests/responses
Mime::Type.register "application/javascript", :js

# Common file upload/download types
Mime::Type.register "application/pdf", :pdf      # PDFs for attachments or reports
Mime::Type.register "image/jpeg", :jpg
Mime::Type.register "image/png", :png
Mime::Type.register "image/webp", :webp          # Modern image format supported by libvips
