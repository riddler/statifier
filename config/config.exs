import Config

# Configure Elixir Logger for enhanced debugging in dev environment
if config_env() == :dev do
  config :logger,
    level: :debug

  config :logger, :console,
    format: "[$level] $message $metadata\n",
    metadata: :all

  # Default Statifier logging configuration for dev
  config :statifier,
    default_log_adapter: :elixir,
    default_log_level: :trace
end

# Test environment uses TestAdapter for clean test output
if config_env() == :test do
  config :logger, level: :warning

  config :statifier,
    default_log_adapter: :test,
    default_log_level: :debug
end
