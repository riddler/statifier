# Configure environment for logging defaults
Application.put_env(:statifier, :environment, :test)

ExUnit.start(exclude: [:scion, :scxml_w3])
