Application.put_env(
  :statifier,
  :default_log_adapter,
  {Statifier.Logging.TestAdapter, [max_entries: 100]}
)

ExUnit.start()
