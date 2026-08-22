*** Amigos Unite API (Portfolio Snapshot) ***

    Production-Grade Rails 7 Backend for Distributed Event Coordination

    This is a sanitized, public snapshot of the private production repository
    for the Amigos Unite API, published for code review by prospective
    employers. It is squashed to a single commit (no production git history)
    and has all secrets, credentials, and VPS access details removed or
    replaced with placeholders — everything else reflects real, running code.

    Live API: https://api.amigosunite.org
    Companion frontend (portfolio snapshot): https://github.com/sagacic-tim/Amigos_Unite_App_Portfolio

** Overview

    Amigos Unite API is a Ruby on Rails 7 API-only backend designed using an API-first architecture. It powers a distributed event coordination platform with stateless JWT authentication, role-based authorization, containerized deployment, and CI/CD automation.

    The system is designed to support SPA clients, mobile clients, and future service integrations.

** Architecture Overview

The backend follows a layered architecture:

    Client (React SPA)

    • RESTful Rails 7 API
    • PostgreSQL Persistence
    • Redis (Sidekiq Background Jobs)
    • External Services (Google Places API)

    Authentication is implemented via Devise + JWT using a stateless model. No server-side sessions are maintained.

    External API keys are protected through server-side proxying.

** Core Capabilities

     • Secure user authentication (Devise + JWT)
     • Role-based event coordination (lead, assistant, participant)
     • Structured event lifecycle management
     • PostgreSQL relational domain modeling
     • Background job processing (Sidekiq)
     • Rate limiting via Rack::Attack
     • CSRF protection strategy
     • Token refresh handling

** Primary API Surface (Representative)

    POST   /api/v1/amigos
    POST   /api/v1/login
    GET    /api/v1/events
    POST   /api/v1/events
    PATCH  /api/v1/events/:id
    POST   /api/v1/event_amigo_connectors
    POST   /api/v1/event_location_connectors
    POST   /api/v1/amigo_location_connectors

    All responses are JSON-only.

** Tech Stack

    • Ruby 3.2.2
    • Rails 7.x (API-only)
    • PostgreSQL 15+
    • Devise + JWT
    • Sidekiq + Redis
    • libvips (image processing)
    • Google Places API
    • Docker / Docker Compose
    • GitHub Actions CI/CD
    • GitHub Container Registry (GHCR)
    • Linux (Ubuntu VPS)
    • Nginx reverse proxy with TLS

** Local Development

    Without Docker

        → bundle install
        → bin/rails db:create
        → bin/rails db:migrate
        → bin/rails s

    With Docker

        → docker compose up --build

** Environment Configuration

    See .env.example for the full list of required environment variables
    (database, mailer, Anthropic/Google API keys, AbuseIPDB, etc). Rails
    credentials (config/master.key) are not included in this repo.

** Testing

    → bundle exec rspec

    Test suite validates:

    • Authentication flows
    • Authorization logic
    • Event lifecycle
    • Location integration

** CI/CD & Deployment

    On push to main:

    1. Run test suite
    2. Build Docker image
    3. Publish image to GHCR
    4. Deploy via image pull to VPS
    5. Restart containers

    Production deployment example:

        docker pull ghcr.io/sagacic-tim/amigos_unite_api:main
        docker compose up -d

** Engineering Focus

    This project demonstrates:

    • Clean domain modeling
    • Secure stateless authentication
    • Role-based authorization
    • Containerized infrastructure
    • CI/CD automation
    • Production deployment ownership
