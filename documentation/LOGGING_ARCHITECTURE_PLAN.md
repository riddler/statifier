# Statifier Logging Architecture Plan

## Overview

This document outlines the planned logging architecture for Statifier, introducing a flexible adapter-based logging system that supports both production and test environments with automatic metadata extraction.

## Key Design Decisions

- **Single Adapter per StateChart**: Simplified approach with one logging adapter per state chart instance
- **Automatic Metadata Extraction**: LogManager automatically extracts core metadata from StateChart
- **Test-Friendly**: TestAdapter stores logs in StateChart for clean test output
- **Configuration-Driven**: Adapter selection via application config or runtime options
- **Breaking Change**: No backward compatibility requirements for this implementation

## Architecture Components

### 1. Adapter Protocol

```elixir
defprotocol Statifier.Logging.Adapter do
  @doc "Log a message at the specified level, returning updated state_chart"
  def log(adapter, state_chart, level, message, metadata)
  
  @doc "Check if a log level is enabled for this adapter"
  def enabled?(adapter, level)
end
```

### 2. StateChart Structure Updates

```elixir
defmodule Statifier.StateChart do
  defstruct [
    # ... existing fields ...
    log_adapter: nil,      # Single adapter instance
    log_level: :info,      # Minimum level for this StateChart  
    logs: []               # Simple array of log entries
  ]
end
```

### 3. Built-in Adapters

#### ElixirLoggerAdapter

- Integrates with Elixir's Logger
- Used in production environments
- Returns unchanged StateChart

#### TestAdapter  

- Stores logs in StateChart's `logs` field
- Prevents test output pollution
- Supports optional max_entries for circular buffer behavior

### 4. LogManager with Automatic Metadata

```elixir
defmodule Statifier.Logging.LogManager do
  @doc "Log with automatic metadata extraction"
  def log(state_chart, level, message, additional_metadata \\ %{})
  
  # Convenience functions
  def trace(state_chart, message, metadata \\ %{})
  def debug(state_chart, message, metadata \\ %{})
  def info(state_chart, message, metadata \\ %{})
  def warn(state_chart, message, metadata \\ %{})
  def error(state_chart, message, metadata \\ %{})
end
```

#### Automatic Core Metadata Extraction

The LogManager automatically extracts:

- `current_state`: Active leaf states from configuration
- `event`: Current event being processed (if any)

Additional metadata can be provided by callers for context-specific information:

- `action_type`: Type of action (log_action, raise_action, assign_action, etc.)
- `phase`: Execution phase (onentry, onexit, transition)
- `target`: Transition target state
- `location`: Assignment location for assign actions

## Configuration

### Application Configuration

```elixir
# config/config.exs (production)
config :statifier,
  default_log_adapter: {Statifier.Logging.ElixirLoggerAdapter, [logger_module: Logger]},
  default_log_level: :info

# config/test.exs (test environment)
config :statifier,
  default_log_adapter: {Statifier.Logging.TestAdapter, [max_entries: 100]},
  default_log_level: :debug
```

### Runtime Configuration

```elixir
{:ok, state_chart} = Interpreter.initialize(document, [
  log_adapter: {Statifier.Logging.TestAdapter, [max_entries: 50]},
  log_level: :trace
])
```

## Usage Examples

### Production Logging

```elixir
# Logs to Elixir Logger with automatic metadata
state_chart = LogManager.info(state_chart, "Processing transition", %{
  target: "next_state",
  action_type: "transition"
})
# Automatically includes current_state and event
```

### Test Logging

```elixir
# Logs stored in state_chart.logs
{:ok, state_chart} = Interpreter.initialize(document)
state_chart = LogManager.debug(state_chart, "Debug info", %{action_type: "test"})

# Inspect captured logs in tests
assert [%{level: :debug, message: "Debug info"}] = state_chart.logs
```

### Migration Examples

#### Before (Current Implementation)

```elixir
Logger.info("Raising event '#{event_name}'")
```

#### After (New Implementation)

```elixir
state_chart = LogManager.info(state_chart, "Raising event '#{event_name}'", %{
  action_type: "raise_action"
})
```

## Implementation Phases

### Phase 1: Core Infrastructure (2 days)

#### Tasks

1. Create `Statifier.Logging.Adapter` protocol
2. Implement `Statifier.Logging.ElixirLoggerAdapter`
3. Implement `Statifier.Logging.TestAdapter`
4. Update `Statifier.StateChart` structure
5. Implement `Statifier.Logging.LogManager` with automatic metadata
6. Add application configuration support
7. Update `Interpreter.initialize/2` to configure logging

### Phase 2: Migration & Testing (1-2 days)

#### Tasks

1. Replace all `Logger.*` calls with `LogManager.*` calls throughout codebase:
   - `lib/statifier/actions/log_action.ex`
   - `lib/statifier/actions/raise_action.ex`
   - `lib/statifier/actions/action_executor.ex`
   - `lib/statifier/actions/assign_action.ex`
   - `lib/statifier/datamodel.ex`
   - `lib/statifier/evaluator.ex`
2. Configure TestAdapter for test environment
3. Update tests to use and inspect `state_chart.logs`
4. Add comprehensive test coverage for logging system
5. Update documentation and examples

## GitHub Issues Breakdown

### Issue 1: Implement Core Logging Infrastructure

- [ ] Create Adapter protocol
- [ ] Implement ElixirLoggerAdapter
- [ ] Implement TestAdapter  
- [ ] Update StateChart structure
- [ ] Create LogManager with automatic metadata extraction

### Issue 2: Add Configuration System

- [ ] Add application configuration support
- [ ] Update Interpreter.initialize/2
- [ ] Add test environment configuration
- [ ] Document configuration options

### Issue 3: Migrate Existing Logger Calls

- [ ] Replace Logger calls in actions modules
- [ ] Replace Logger calls in datamodel module
- [ ] Replace Logger calls in evaluator module
- [ ] Update all metadata to use new pattern

### Issue 4: Test Integration

- [ ] Configure TestAdapter for test suite
- [ ] Update existing tests for new logging
- [ ] Add logging-specific test cases
- [ ] Verify clean test output

### Issue 5: Documentation & Examples

- [ ] Update API documentation
- [ ] Add usage examples
- [ ] Update CHANGELOG.md
- [ ] Create migration guide

## Benefits

1. **Clean Test Output**: TestAdapter prevents log pollution during test runs
2. **Consistent Metadata**: Automatic extraction ensures uniform logging
3. **Flexible Configuration**: Easy switching between adapters via config
4. **Future-Ready**: Foundation for GenServer-based long-lived interpreters
5. **Simplified API**: Callers only provide context-specific metadata
6. **Type Safety**: Protocol-based design with clear contracts

## Future Enhancements

- Multiple adapters per StateChart (if needed)
- Runtime logging reconfiguration helpers
- Additional built-in adapters (File, Database, etc.)
- Log filtering and routing capabilities
- Performance optimizations for high-throughput scenarios
- Integration with distributed tracing systems

## Notes

- This is a breaking change - no backward compatibility maintained
- TestAdapter stores logs in StateChart, not in adapter instance
- Log level filtering happens at both StateChart and Adapter levels
- Metadata extraction is automatic but can be overridden when needed
