# Statifier - SCXML State Machines for Elixir

[![CI](https://github.com/riddler/statifier/actions/workflows/ci.yml/badge.svg)](https://github.com/riddler/statifier/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/riddler/statifier/branch/main/graph/badge.svg)](https://codecov.io/gh/riddler/statifier)
[![Hex.pm Version](https://img.shields.io/hexpm/v/statifier.svg)](https://hex.pm/packages/statifier)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/statifier/)

> 📦 **This repository is archived. Development has moved to [riddler/statifier-ex](https://github.com/riddler/statifier-ex).**  
> statifier-ex is a ground-up rewrite of this engine and will publish as `statifier` 2.0 on Hex.  
> This repository stays here, read-only, as the v1 history. **The 1.9.x releases remain on Hex and are usable as-is** - `{:statifier, "~> 1.9"}` keeps working exactly as it does today, but 1.x will not see further development.

An Elixir implementation of SCXML (State Chart XML) state charts with a focus on W3C compliance.

## Installation

Add `statifier` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:statifier, "~> 1.9"}
  ]
end
```

For comprehensive examples and usage patterns, see the [Getting Started Guide](https://riddler.github.io/statifier/getting-started).

## Quick Example

```elixir
# Simple traffic light state machine
xml = """
<scxml initial="red">
  <state id="red">
    <transition event="timer" target="green"/>
  </state>
  <state id="green">
    <transition event="timer" target="yellow"/>
  </state>
  <state id="yellow">
    <transition event="timer" target="red"/>
  </state>
</scxml>
"""

# Parse and initialize
{:ok, document, _warnings} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.initialize(document)

# Check active state
Statifier.active_leaf_states(state_chart)
# MapSet.new(["red"])

# Send events to transition between states  
{:ok, state_chart} = Statifier.send_sync(state_chart, "timer")

# Check active state
Statifier.active_leaf_states(state_chart)
# MapSet.new(["green"])
```

## Documentation

For comprehensive guides, examples, and technical details, see the [Statifier Documentation](https://riddler.github.io/statifier):

- **[Getting Started](https://riddler.github.io/statifier/getting-started)** - Build your first state machine with working examples
- **[External Services](https://riddler.github.io/statifier/external-services)** - Secure integration with APIs and external systems  
- **[Installation Guide](https://riddler.github.io/statifier/installation)** - Set up Statifier in your project
- **[Roadmap](https://riddler.github.io/statifier/roadmap)** - Planned features and priorities

## Resources

- **[GitHub Repository](https://github.com/riddler/statifier)** - Source code and issues  
- **[Hex Package](https://hex.pm/packages/statifier)** - Package information
- **[HexDocs API](https://hexdocs.pm/statifier/)** - Complete API documentation

For comprehensive technical details about the implementation, see the [Architecture Documentation](https://riddler.github.io/statifier/architecture).
