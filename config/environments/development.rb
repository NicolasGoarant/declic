require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Reload code on every request — slower but ideal for development.
  config.enable_reloading = true
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Server timing
  config.server_timing = true

  # Caching (disabled by default)
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  # Active Storage local
  config.active_storage.service = :local

  # Mailer
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false

  # URL helpers
  config.action_mailer.default_url_options = {
    host: "localhost",
    port: 3000
  }

  # 👉 MAILER : utilise letter_opener en développement
  config.action_mailer.perform_deliveries = true
  config.action_mailer.delivery_method = :letter_opener

  # Deprecations
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  # Raise if migrations are pending
  config.active_record.migration_error = :page_load

  # Verbose SQL logs
  config.active_record.verbose_query_logs = true

  # Verbose ActiveJob logs
  config.active_job.verbose_enqueue_logs = true

  # Silence asset logs
  config.assets.quiet = true

  # Show filenames in view annotations
  config.action_view.annotate_rendered_view_with_filenames = true

  # Raise errors for bad before_action configs
  config.action_controller.raise_on_missing_callback_actions = true

end
