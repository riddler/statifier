import Config

# Logger configuration for examples
config :logger,
  level: :debug  # Allow debug/trace logs for detailed state machine debugging

# Example-specific configuration
config :statifier_examples,
  # Default notification settings (can be overridden per example)
  notifications: [
    email_enabled: false,
    webhook_enabled: false,
    console_logging: true
  ]