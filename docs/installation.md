# Installation

## Requirements

- Elixir 1.17+
- Erlang/OTP 26+

## Adding to Your Project

Add `statifier` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:statifier, "~> 1.9"}
  ]
end
```

Then run:

```bash
mix deps.get
mix compile
```

## Verification

To verify your installation works correctly, you can run this simple test:

```elixir
# Create a basic SCXML document
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
  <state id="start">
    <transition event="go" target="end"/>
  </state>
  <state id="end"/>
</scxml>
"""

# Parse and initialize
{:ok, document, _warnings} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.initialize(document)

# Should output: MapSet containing "start"
IO.inspect(Statifier.Configuration.active_leaf_states(state_chart.configuration))
```

If this runs without errors and outputs `#MapSet<["start"]>`, your installation is working correctly.

## Next Steps

- **[Getting Started Guide](/getting-started)** - Build your first state machine with working examples
- **[External Services](/external-services)** - Learn about secure integration with APIs and external systems
- **[API Documentation](https://hexdocs.pm/statifier/)** - Explore the complete API reference
