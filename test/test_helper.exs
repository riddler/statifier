# Configure test environment to use TestAdapter for clean test output
Application.put_env(
  :statifier,
  :default_log_adapter,
  {Statifier.Logging.TestAdapter, [max_entries: 100]}
)

Application.put_env(:statifier, :default_log_level, :debug)

ExUnit.start(exclude: [:benchmark, :scion, :scxml_w3])
