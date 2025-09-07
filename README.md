# Statifier - SCXML State Machines for Elixir

[![CI](https://github.com/riddler/statifier/actions/workflows/ci.yml/badge.svg)](https://github.com/riddler/statifier/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/riddler/statifier/branch/main/graph/badge.svg)](https://codecov.io/gh/riddler/statifier)
[![Hex.pm Version](https://img.shields.io/hexpm/v/statifier.svg)](https://hex.pm/packages/statifier)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/statifier/)

> ⚠️ **Active Development Notice**  
> This project is still under active development and things may change even though it is passed version 1. APIs, features, and behaviors may evolve as we continue improving SCXML compliance and functionality.

An Elixir implementation of SCXML (State Chart XML) state charts with a focus on W3C compliance.

## Features

- ✅ **Complete SCXML Parser** - Converts XML documents to structured data with precise location tracking
- ✅ **State Chart Interpreter** - Runtime engine for executing SCXML state charts  
- ✅ **Secure Invoke System** - Handler-based external service integration with SCXML compliance
- ✅ **Modular Validation** - Document validation with focused sub-validators for maintainability
- ✅ **Compound States** - Support for hierarchical states with automatic initial child entry
- ✅ **Initial State Elements** - Full support for `<initial>` elements with transitions (W3C compliant)
- ✅ **Parallel States** - Support for concurrent state regions with simultaneous execution
- ✅ **Eventless Transitions** - Automatic transitions without event attributes (W3C compliant)
- ✅ **Conditional Transitions** - Full support for `cond` attributes with expression evaluation
- ✅ **Executable Content** - Complete support for `<assign>`, `<log>`, `<raise>`, `<if>`, `<invoke>` elements
- ✅ **Parameter Processing** - Unified parameter evaluation for `<send>` and `<invoke>` elements
- ✅ **Value Evaluation** - Non-boolean expression evaluation using Predicator v3.0 for actual data values
- ✅ **Data Model Integration** - StateChart data model with dynamic variable assignment and persistence
- ✅ **O(1) Performance** - Optimized state and transition lookups via Maps
- ✅ **Event Processing** - Internal and external event queues per SCXML specification
- ✅ **Parse → Validate → Optimize Architecture** - Clean separation of concerns
- ✅ **Feature Detection** - Automatic SCXML feature detection for test validation
- ✅ **Regression Testing** - Automated tracking of passing tests to prevent regressions
- ✅ **Git Hooks** - Pre-push validation workflow to catch issues early
- ✅ **Logging Infrastructure** - Protocol-based logging system with TestAdapter for clean test environments
- ✅ **Test Infrastructure** - Compatible with SCION and W3C test suites with integrated logging
- ✅ **Code Quality** - Full Credo compliance with proper module aliasing
- ✅ **History States** - Complete shallow and deep history state support per W3C SCXML specification
- ✅ **Multiple Transition Targets** - Support for space-separated multiple targets in transitions

## Current Status

### Working Features

- ✅ **Basic state transitions** and event-driven changes
- ✅ **Hierarchical states** with optimized O(1) state lookup and automatic initial child entry  
- ✅ **Initial state elements** - Full `<initial>` element support with transitions and comprehensive validation
- ✅ **Parallel states** with concurrent execution of multiple regions and proper cross-boundary exit semantics
- ✅ **Eventless transitions** - Automatic transitions without event attributes (also called NULL transitions in SCXML spec), with cycle detection and microstep processing
- ✅ **Conditional transitions** - Full `cond` attribute support with Predicator v3.0 expression evaluation and SCXML `In()` function
- ✅ **Assign elements** - Complete `<assign>` element support with location-based assignment, nested property access, and mixed notation
- ✅ **If/Else/ElseIf conditional actions** - Complete `<if>`, `<elseif>`, `<else>` conditional execution blocks
- ✅ **Invoke elements** - Secure `<invoke>` element support with handler-based external service integration and SCXML-compliant event generation
- ✅ **Parameter processing** - Unified `<param>` element evaluation with strict/lenient error handling modes
- ✅ **Value evaluation system** - Enhanced Evaluator module with centralized parameter processing and non-boolean expression evaluation
- ✅ **Enhanced expression evaluation** - Predicator v3.0 integration with deep property access and type-safe operations
- ✅ **History states** - Complete shallow and deep history state implementation with recording, restoration, and validation
- ✅ **Multiple transition targets** - Support for space-separated multiple targets (e.g., `target="state1 state2"`)
- ✅ **Enhanced parallel state exit logic** - Proper W3C SCXML exit set computation for complex parallel hierarchies
- ✅ **Transition conflict resolution** - Child state transitions take priority over ancestor transitions per W3C specification
- ✅ **SCXML-compliant processing** - Proper microstep/macrostep execution model with exit set computation and LCCA algorithms
- ✅ **Modular validation** - Refactored from 386-line monolith into focused sub-validators
- ✅ **Feature detection** - Automatic SCXML feature detection prevents false positive test results
- ✅ **SAX-based XML parsing** with accurate location tracking for error reporting
- ✅ **Performance optimizations** - O(1) state/transition lookups, optimized active configuration
- ✅ **Source field optimization** - Transitions include source state for faster event processing
- ✅ **Comprehensive logging** - Protocol-based logging system with structured metadata and test environment integration

### Planned Features

- Internal and targetless transitions
- More executable content (`<script>`, `<send>`, etc.)
- Enhanced datamodel support with JavaScript expression engine
- Enhanced validation for complex SCXML constructs

## Documentation

For comprehensive guides, examples, and technical details, see the [Statifier Documentation](https://riddler.github.io/statifier):

- **[Getting Started](https://riddler.github.io/statifier/getting-started)** - Build your first state machine with working examples
- **[External Services](https://riddler.github.io/statifier/external-services)** - Secure integration with APIs and external systems  
- **[Changelog](https://riddler.github.io/statifier/changelog)** - Recent major feature completions
- **[Roadmap](https://riddler.github.io/statifier/roadmap)** - Planned features and priorities

## Quick Example

```elixir
# Simple traffic light state machine
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

# Parse and initialize
{:ok, document, _warnings} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.initialize(document)

# Send events to transition between states  
{:ok, state_chart} = Statifier.send_sync(state_chart, "timer")
```

## Installation

Add `statifier` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:statifier, "~> 1.8"}
  ]
end
```

For comprehensive examples and usage patterns, see the [Getting Started Guide](https://riddler.github.io/statifier/getting-started).

## Learn More

- **[Getting Started](https://riddler.github.io/statifier/getting-started)** - Build your first state machine with working examples
- **[External Services](https://riddler.github.io/statifier/external-services)** - Integrate safely with APIs and external systems
- **[Installation Guide](https://riddler.github.io/statifier/installation)** - Set up Statifier in your project

## Project Information

- **[Architecture](https://riddler.github.io/statifier/architecture)** - Technical design and component overview
- **[Changelog](https://riddler.github.io/statifier/changelog)** - Recent major feature completions and implementation details
- **[Roadmap](https://riddler.github.io/statifier/roadmap)** - Planned features and development priorities

## Resources

- **[GitHub Repository](https://github.com/riddler/statifier)** - Source code and issues  
- **[Hex Package](https://hex.pm/packages/statifier)** - Package information
- **[HexDocs API](https://hexdocs.pm/statifier/)** - Complete API documentation

---

::: info Active Development Notice
This project is under active development. While stable for production use, APIs may evolve as we continue improving SCXML compliance and functionality.
:::

For comprehensive technical details about the implementation, see the [Architecture Documentation](https://riddler.github.io/statifier/architecture).
