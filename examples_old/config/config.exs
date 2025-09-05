import Config

# Logger configuration for examples
config :logger,
  # Allow debug/trace logs for detailed state machine debugging
  level: :debug

# Example-specific configuration
config :statifier_examples,
  # Default notification settings (can be overridden per example)
  notifications: [
    email_enabled: false,
    webhook_enabled: false,
    console_logging: true
  ]
