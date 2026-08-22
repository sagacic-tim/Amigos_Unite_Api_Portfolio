# amigos_unite_api/Dockerfile

# ---- Base image: Ruby + system deps for Rails + Postgres + image_processing ----
FROM ruby:3.2.2-bookworm

# Install OS packages needed by:
# - pg (PostgreSQL client & headers)
# - image_processing / vips
# - general build tooling
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      postgresql-client \
      libvips \
      git \
      curl \
      ca-certificates \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# ---- Ruby / Bundler setup ----
ENV BUNDLE_PATH=/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# Copy only Gemfile + lockfile first, to leverage Docker layer cache
COPY Gemfile Gemfile.lock ./

# Install gems (without development/test by default for this image)
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

# ---- Copy application code ----
COPY . .

# ---- Environment defaults for the container ----
# We want this container to behave like a production-style API:
#  - plain HTTP inside container on PORT (TLS handled by a reverse proxy)
#  - Rails production config (respecting RAILS_MASTER_KEY at runtime)
ENV RAILS_ENV=production \
    RACK_ENV=production \
    PORT=3001 \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# Precompile assets if you ever add them; for API-only this is usually a no-op,
# but we keep it here so the image works even if you add views/assets later.
# You can comment this out if it causes trouble.
RUN bundle exec rake assets:precompile || echo "No assets to precompile"

# Expose the Puma port
EXPOSE 3001

# Default command: run Puma using your existing config/puma.rb
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
