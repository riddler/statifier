import Config

# Logger configuration for examples
config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

# Example-specific configuration
config :statifier_examples,
  # Default notification settings (can be overridden per example)
  notifications: [
    email_enabled: false,
    webhook_enabled: false,
    console_logging: true
  ]