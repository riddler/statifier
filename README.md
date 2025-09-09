# Statifier - SCXML State Machines for Elixir

[![CI](https://github.com/riddler/statifier/actions/workflows/ci.yml/badge.svg)](https://github.com/riddler/statifier/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/riddler/statifier/branch/main/graph/badge.svg)](https://codecov.io/gh/riddler/statifier)
[![Hex.pm Version](https://img.shields.io/hexpm/v/statifier.svg)](https://hex.pm/packages/statifier)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/statifier/)

> ⚠️ **Active Development Notice**  
> This project is still under active development and things may change even though it is passed version 1. APIs, features, and behaviors may evolve as we continue improving SCXML compliance and functionality.

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
