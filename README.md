# SC - StateCharts for Elixir

[![CI](https://github.com/riddler/sc/workflows/CI/badge.svg)](https://github.com/riddler/sc/actions)
[![Coverage](https://codecov.io/gh/riddler/sc/branch/main/graph/badge.svg)](https://codecov.io/gh/riddler/sc)

An Elixir implementation of SCXML (State Chart XML) state charts with a focus on W3C compliance.

## Features

- ✅ **Complete SCXML Parser** - Converts XML documents to structured data with precise location tracking
- ✅ **State Chart Interpreter** - Runtime engine for executing SCXML state charts  
- ✅ **Comprehensive Validation** - Document validation with detailed error reporting
- ✅ **Compound States** - Support for hierarchical states with automatic initial child entry
- ✅ **O(1) Performance** - Optimized state and transition lookups via Maps
- ✅ **Event Processing** - Internal and external event queues per SCXML specification
- ✅ **Parse → Validate → Optimize Architecture** - Clean separation of concerns
- ✅ **Pre-push Hook** - Automated local validation workflow to catch issues early
- ✅ **Test Infrastructure** - Compatible with SCION and W3C test suites

## Current Status

**SCION Test Results:** 107/225 tests passing (47.6% pass rate)

### Working Features
- Basic state transitions and event-driven changes
- Hierarchical states with optimized O(d) ancestor lookup using parent pointers
- Document validation and error reporting with comprehensive hierarchy checks
- SAX-based XML parsing with accurate location tracking
- Performance-optimized active configuration generation

### Planned Features
- Parallel states (`<parallel>`)
- History states (`<history>`) 
- Conditional transitions with expression evaluation
- Executable content (`<script>`, `<assign>`, `<send>`, etc.)
- Enhanced validation for complex SCXML constructs

## Installation

Add `sc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sc, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic Example

```elixir
# Parse SCXML document
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
  <state id="start">
    <transition event="go" target="end"/>
  </state>
  <state id="end"/>
</scxml>
"""

{:ok, document} = SC.Parser.SCXML.parse(xml)

# Initialize state chart
{:ok, state_chart} = SC.Interpreter.initialize(document)

# Check active states
active_states = SC.Interpreter.active_states(state_chart)
# Returns: MapSet.new(["start"])

# Send event
event = SC.Event.new("go")
{:ok, new_state_chart} = SC.Interpreter.send_event(state_chart, event)

# Check new active states
active_states = SC.Interpreter.active_states(new_state_chart)
# Returns: MapSet.new(["end"])
```

### Document Validation

```elixir
{:ok, document} = SC.Parser.SCXML.parse(xml)

case SC.Document.Validator.validate(document) do
  {:ok, optimized_document, warnings} -> 
    # Document is valid and optimized, warnings are non-fatal
    IO.puts("Valid document with #{length(warnings)} warnings")
    # optimized_document now has O(1) lookup maps built
  {:error, errors, warnings} ->
    # Document has validation errors
    IO.puts("Validation failed with #{length(errors)} errors")
end
```

## Development

### Requirements

- Elixir 1.17+ 
- Erlang/OTP 26+

### Setup

```bash
mix deps.get
mix compile
```

### Code Quality Workflow

The project maintains high code quality through automated checks:

```bash
# Local validation workflow (also runs via pre-push hook)
mix format
mix test --cover
mix credo --strict
mix dialyzer
```

### Pre-push Hook

A git pre-push hook automatically runs the validation workflow to catch issues before CI:

```bash
git push origin feature-branch
# Automatically runs: format check, tests, credo, dialyzer
# Push is blocked if any step fails
```

### Running Tests

```bash
# All tests
mix test

# With coverage
mix coveralls

# SCION basic tests
mix test --include scion --include spec:basic --exclude scxml_w3

# Specific test file
mix test test/sc/parser/scxml_test.exs
```

## Architecture

### Core Components

- **`SC.Parser.SCXML`** - SAX-based XML parser with location tracking (parse phase)
- **`SC.Document.Validator`** - Comprehensive validation with optimization (validate + optimize phases)
- **`SC.Interpreter`** - Synchronous state chart interpreter with compound state support
- **`SC.StateChart`** - Runtime container with event queues
- **`SC.Configuration`** - Active state management (leaf states only)
- **`SC.Event`** - Event representation with origin tracking

### Data Structures

- **`SC.Document`** - Root SCXML document with states, metadata, and O(1) lookup maps
- **`SC.State`** - Individual states with transitions and hierarchical nesting support
- **`SC.Transition`** - State transitions with events and targets
- **`SC.DataElement`** - Datamodel elements with expressions

### Architecture Flow

```elixir
# 1. Parse: XML → Document structure
{:ok, document} = SC.Parser.SCXML.parse(xml)

# 2. Validate: Check semantics + optimize with lookup maps  
{:ok, optimized_document, warnings} = SC.Document.Validator.validate(document)

# 3. Interpret: Run state chart with optimized lookups
{:ok, state_chart} = SC.Interpreter.initialize(optimized_document)
```

## Performance Optimizations

The implementation includes several key optimizations for production use:

### **O(1) State and Transition Lookups**
- **State Lookup Map**: `%{state_id => state}` for instant state access
- **Transition Lookup Map**: `%{state_id => [transitions]}` for fast transition queries  
- **Built During Validation**: Lookup maps only created for valid documents
- **Memory Efficient**: Uses existing document structure, no duplication

### **Compound State Entry**
```elixir
# Automatic hierarchical entry
{:ok, state_chart} = SC.Interpreter.initialize(document)
active_states = SC.Interpreter.active_states(state_chart)
# Returns only leaf states (compound states entered automatically)

# Fast ancestor computation when needed
ancestors = SC.Interpreter.active_ancestors(state_chart) 
# O(1) state lookups + O(d) ancestor traversal
```

### **Parse → Validate → Optimize Flow**
- **Separation of Concerns**: Parser focuses on structure, validator on semantics
- **Conditional Optimization**: Only builds lookup maps for valid documents
- **Future-Proof**: Supports additional parsers (JSON, YAML) with same validation

**Performance Impact:**
- O(1) vs O(n) state lookups during interpretation
- O(1) vs O(n) transition queries for event processing  
- Critical for responsive event processing in complex state charts

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the code quality workflow
4. Add tests for new functionality
5. Ensure all CI checks pass
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Code Style

- All code is formatted with `mix format`
- Static analysis with Credo (strict mode)
- Type checking with Dialyzer
- Comprehensive test coverage (95%+ maintained)
- Detailed documentation with `@moduledoc` and `@doc`
- Pattern matching preferred over multiple assertions in tests

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [W3C SCXML Specification](https://www.w3.org/TR/scxml/) - Official specification
- [SCION Test Suite](https://github.com/jbeard4/SCION) - Comprehensive test cases
- [ex_statechart](https://github.com/camshaft/ex_statechart) - Reference implementation

