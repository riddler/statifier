# Getting Started with Statifier

Welcome to Statifier! This guide will walk you through setting up your first SCXML state machine.

## Installation

Add `statifier` to your list of dependencies in `mix.exs`:

```elixir
{:statifier, "~> 1.7"}
```

Then run:

```bash
mix deps.get
```

## Your First State Machine

Let's create a simple state machine for a traffic light:

```elixir
# Define the SCXML document
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="red">
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

# Parse the document
{:ok, document, warnings} = Statifier.parse(xml)

# Initialize the state chart
{:ok, state_chart} = Statifier.Interpreter.initialize(document)

# Check current state
IO.inspect(Statifier.Configuration.active_leaf_states(state_chart.configuration))
# [:red]

# Send an event
{:ok, new_state_chart} = Statifier.send_sync(state_chart, "timer")

# Check new state  
IO.inspect(Statifier.Configuration.active_leaf_states(new_state_chart.configuration))
# [:green]
```

## Understanding the Flow

Statifier follows a clean **Parse → Validate → Optimize** architecture:

1. **Parse**: Convert XML string to structured document
2. **Validate**: Check semantic correctness and build optimization maps  
3. **Execute**: Use optimized document for high-performance runtime

## Key Components

- **`Statifier.parse/1`** - Main entry point for parsing SCXML
- **`Statifier.Interpreter`** - Core runtime engine for state chart execution
- **`Statifier.Event`** - Represents events sent to the state machine
- **`Statifier.Configuration`** - Tracks active states and provides state queries

## Next Steps

Now that you have the basics working, explore these topics:

- **Hierarchical States** - Nested states with parent-child relationships
- **Parallel States** - Concurrent execution of multiple state regions  
- **Conditional Transitions** - Event processing with conditional logic
- **Data Model** - Working with variables and expressions
- **History States** - Remembering previous state configurations

## Getting Help

- **[API Documentation](https://hexdocs.pm/statifier/)** - Complete function reference
- **[GitHub Issues](https://github.com/riddler/statifier/issues)** - Report bugs or request features
- **[Examples Repository](https://github.com/riddler/statifier/tree/master/test)** - Browse test files for more examples
