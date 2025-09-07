# Getting Started with Statifier

Statifier is an Elixir implementation of SCXML (State Chart XML) state machines with a focus on W3C compliance. This guide will help you build your first state machine.

## Installation

Add `statifier` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:statifier, "~> 1.7"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Your First State Machine

Let's create a simple traffic light state machine:

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

# Parse and initialize the state chart
{:ok, document, _warnings} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.initialize(document)

# Check the initial state
IO.puts("Current state: #{inspect(state_chart.configuration.active_states)}")
# Output: Current state: #MapSet<["red"]>

# Send events to transition between states
{:ok, state_chart} = Statifier.send_sync(state_chart, "timer")
IO.puts("After timer: #{inspect(state_chart.configuration.active_states)}")
# Output: After timer: #MapSet<["green"]>

{:ok, state_chart} = Statifier.send_sync(state_chart, "timer")
IO.puts("After timer: #{inspect(state_chart.configuration.active_states)}")
# Output: After timer: #MapSet<["yellow"]>

{:ok, state_chart} = Statifier.send_sync(state_chart, "timer")
IO.puts("After timer: #{inspect(state_chart.configuration.active_states)}")
# Output: After timer: #MapSet<["red"]>
```

## Working with Data

Statifier supports data models and expressions for dynamic state machines:

```elixir
xml_with_data = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="checking">
  <datamodel>
    <data id="balance" expr="100"/>
    <data id="amount" expr="0"/>
  </datamodel>
  
  <state id="checking">
    <onentry>
      <assign location="amount" expr="50"/>
    </onentry>
    <transition event="withdraw" target="approved" cond="balance >= amount"/>
    <transition event="withdraw" target="denied" cond="balance < amount"/>
  </state>
  
  <state id="approved"/>
  <state id="denied"/>
</scxml>
"""

{:ok, document, _warnings} = Statifier.parse(xml_with_data)
{:ok, state_chart} = Statifier.initialize(document)

# The state chart starts with balance=100, amount=50 (set in onentry)
{:ok, state_chart} = Statifier.send_sync(state_chart, "withdraw")
IO.puts("Withdrawal result: #{inspect(state_chart.configuration.active_states)}")
# Output: Withdrawal result: #MapSet<["approved"]>
```

## Next Steps

Now that you have a basic state machine running, you can explore more advanced features:

- **Hierarchical States**: Create nested states with automatic initial child entry
- **Parallel States**: Run multiple state regions concurrently  
- **History States**: Save and restore previous states
- **External Services**: Integrate with APIs and external systems using the secure invoke system
- **Conditional Logic**: Use complex expressions in transition conditions

For more examples, see the README.md file in the repository.