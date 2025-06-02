
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RubyGitopsApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments/, which are processed later.
    
    # Time zone
    config.time_zone = 'UTC'
    
    # Eager load paths
    config.eager_load_paths << Rails.root.join("app", "services")
    config.eager_load_paths << Rails.root.join("app", "jobs")
    
    # API configuration
    config.api_only = false
    
    # CORS configuration
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins Rails.env.development? ? '*' : ['https://ruby-app.buildwithsushant.com']
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          credentials: true
      end
    end
    
    # Session store
    config.session_store :cookie_store, key: '_ruby_gitops_session'
    
    # Active Job queue adapter
    config.active_job.queue_adapter = :sidekiq
    
    # Cache store
    config.cache_store = :redis_cache_store, {
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
      pool_size: ENV.fetch('RAILS_MAX_THREADS', 5).to_i,
      pool_timeout: 5
    }
    
    # Active Storage
    config.active_storage.variant_processor = :mini_magick
    
    # Logging
    if Rails.env.production?
      config.log_level = :info
      config.lograge.enabled = true
      config.lograge.formatter = Lograge::Formatters::Json.new
      config.lograge.custom_options = lambda do |event|
        {
          timestamp: Time.current.iso8601,
          host: Socket.gethostname,
          request_id: event.payload[:headers]['X-Request-Id']
        }
      end
    end
    
    # Security
    config.force_ssl = Rails.env.production?
    config.ssl_options = {
      redirect: { exclude: ->(request) { request.path.start_with?('/health') } }
    }
    
    # Generator configuration
    config.generators do |g|
      g.test_framework :rspec, fixtures: false
      g.factory_bot dir: 'spec/factories'
      g.skip_routes true
      g.helper false
      g.assets false
    end
    
    # Health check configuration
    config.health_check.uri = 'health'
    config.health_check.success = 200
    config.health_check.verbose = false
    config.health_check.include_error_in_response_body = false
    
    # Custom middleware
    config.middleware.use ActionDispatch::RequestId
    
    # Exception handling
    config.exceptions_app = ->(env) { ErrorsController.action(:show).call(env) }
  end
end
