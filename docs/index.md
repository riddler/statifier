---
layout: home

hero:
  name: Statifier
  text: SCXML State Machines for Elixir
  tagline: Complete W3C compliant implementation with high-performance state chart execution
  actions:
    - theme: brand
      text: Get Started
      link: /tutorials/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/riddler/statifier

features:
  - icon: ⚡
    title: High Performance
    details: O(1) state and transition lookups with optimized Maps for fast state chart execution
  - icon: 🎯
    title: W3C Compliant
    details: Full SCXML specification compliance with comprehensive test coverage from SCION and W3C test suites
  - icon: 🔧
    title: Complete Feature Set
    details: Hierarchical states, parallel execution, history states, conditional transitions, and executable content
  - icon: 🧪
    title: Test-Driven
    details: 707 internal tests with 92.3% coverage, plus 118 regression tests ensuring reliability
  - icon: 🏗️
    title: Clean Architecture
    details: Parse → Validate → Optimize pipeline with modular validation and clear separation of concerns
  - icon: 📊
    title: Advanced Logging
    details: Protocol-based logging system with TestAdapter for development and ElixirLoggerAdapter for production
---

## What is Statifier?

Statifier is an Elixir implementation of **SCXML (State Chart XML)** state machines with a focus on W3C compliance. It provides a complete runtime engine for executing complex state charts with hierarchical states, parallel execution, and advanced features like history states and conditional transitions.

## Key Features

### ✅ Complete SCXML Implementation

- **Hierarchical States**: Nested states with automatic initial child entry
- **Parallel States**: Concurrent state regions with proper exit semantics  
- **History States**: Shallow and deep history state support per W3C specification
- **Conditional Transitions**: Full expression evaluation with SCXML `In()` function
- **Executable Content**: Complete `<assign>`, `<if>`, `<log>`, and `<raise>` element support

### ✅ High Performance Design

- **O(1 Lookups**: Optimized state and transition maps for fast execution
- **Efficient Memory Usage**: Stores only leaf states with dynamic ancestor computation
- **Cycle Detection**: Prevents infinite loops in eventless transitions
- **Optimized Parsing**: SAX-based XML parsing with precise location tracking

### ✅ Production Ready

- **Comprehensive Testing**: 707 internal tests with 92.3% code coverage
- **Regression Protection**: 118 critical functionality tests prevent regressions
- **Git Hooks**: Pre-push validation workflow catches issues early
- **Clean Code**: Full Credo compliance with proper documentation

## Quick Example

```elixir
# Parse SCXML document
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="idle">
  <state id="idle">
    <transition event="start" target="running"/>
  </state>
  <state id="running">
    <transition event="stop" target="idle"/>
  </state>
</scxml>
"""

# Initialize state chart
{:ok, document, _warnings} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.initialize(document)

# Process events
{:ok, new_state_chart} = Statifier.send_sync(state_chart, "start")
```

## Installation

Add `statifier` to your list of dependencies in `mix.exs`:

```elixir
{:statifier, "~> 1.7"}
```

## Learn More

- **[Getting Started](/getting-started)** - Build your first state machine with working examples
- **[External Services](/external-services)** - Integrate safely with APIs and external systems
- **[Installation Guide](/installation)** - Set up Statifier in your project

## Project Information

- **[Architecture](/architecture)** - Technical design and component overview
- **[Changelog](/changelog)** - Recent major feature completions and implementation details
- **[Roadmap](/roadmap)** - Planned features and development priorities

## Resources

- **[GitHub Repository](https://github.com/riddler/statifier)** - Source code and issues  
- **[Hex Package](https://hex.pm/packages/statifier)** - Package information
- **[HexDocs API](https://hexdocs.pm/statifier/)** - Complete API documentation

---

::: info Active Development Notice
This project is under active development. While stable for production use, APIs may evolve as we continue improving SCXML compliance and functionality.
:::
