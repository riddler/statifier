# StatifierExamples

A collection of real-world examples demonstrating how to use **Statifier** - a robust SCXML-based state machine library for Elixir applications.

## Overview

This umbrella application contains multiple sub-applications, each showcasing different aspects of building production-ready workflows with Statifier. Each example includes:

- **Complete implementation** using Statifier's GenServer-based state machines
- **Comprehensive test suites** demonstrating testing patterns and best practices
- **Production-ready patterns** including error handling, logging, and supervision
- **Real-world business scenarios** with practical use cases

## Examples

### approval_workflow

A comprehensive purchase order approval workflow demonstrating:

- **Multi-level approval processes** based on business rules (amount thresholds)
- **Conditional routing** using SCXML expressions for dynamic workflow paths
- **Data model integration** with `_event.data` assignment and persistence
- **Business logic callbacks** for notifications, logging, and external system integration
- **State persistence** across long-running business processes
- **Comprehensive test coverage** including boundary value testing

**Key Features Showcased:**

- SCXML conditional transitions with `cond` attributes
- GenServer-based long-lived state machines
- Business process automation patterns
- Data model management and assignment actions
- Production logging and error handling

[View the approval_workflow example →](apps/approval_workflow/)

## Getting Started

### Prerequisites

- Elixir 1.15+ with OTP 25+
- Statifier library (included as dependency)

### Running Examples

```bash
# Clone the repository and navigate to examples
cd examples

# Install dependencies
mix deps.get

# Start an interactive session to explore examples
iex -S mix

# Run a specific example (e.g., approval workflow)
iex> {:ok, pid} = ApprovalWorkflow.PurchaseOrderMachine.start_link()
iex> ApprovalWorkflow.PurchaseOrderMachine.submit_po(pid, %{
...>   po_id: "DEMO-001",
...>   amount: 2500,
...>   requester: "demo@company.com"
...> })
```

### Running Tests

```bash
# Run all tests across all examples
mix test

# Run tests for a specific example
mix test apps/approval_workflow/test/
```

## Architecture

The examples are structured as an Elixir umbrella application to demonstrate:

- **Modular design** - Each example is a separate Mix application
- **Shared dependencies** - Common libraries managed at the umbrella level
- **Independent testing** - Each example has its own comprehensive test suite
- **Production patterns** - Proper OTP application structure and supervision

### Project Structure

```text
examples/
├── apps/                           # Individual example applications
│   └── approval_workflow/          # Purchase order approval workflow
│       ├── lib/                    # Implementation code
│       ├── test/                   # Comprehensive test suite
│       ├── priv/scxml/            # SCXML state machine definitions
│       └── README.md              # Detailed example documentation
├── mix.exs                        # Umbrella project configuration
└── README.md                      # This file
```

## Learning Path

1. **Start with approval_workflow** - Comprehensive example covering most Statifier features
2. **Explore the test suites** - Learn testing patterns for state machine applications  
3. **Study the SCXML definitions** - Understand how business logic translates to state machines
4. **Examine callback implementations** - See how to integrate business logic with state transitions

## Key Concepts Demonstrated

### State Machine Design Patterns

- **Hierarchical states** with automatic child state entry
- **Conditional transitions** based on business rules and data
- **Event-driven workflows** with proper event handling
- **Data model integration** for persistent workflow state

### Elixir/OTP Integration

- **GenServer-based state machines** for long-running processes
- **Supervision trees** for fault tolerance
- **Process registration and discovery** patterns
- **Comprehensive logging** for observability

### Testing Strategies

- **Unit testing** of individual state transitions
- **Integration testing** of complete workflow scenarios
- **Boundary value testing** for conditional logic
- **Data persistence validation** across state transitions

### Production Considerations

- **Error handling** and graceful degradation
- **Logging and observability** for debugging and monitoring
- **Performance optimization** with efficient state lookups
- **Code quality** with comprehensive type specs and documentation

## Contributing

Each example should demonstrate real-world usage patterns and include:

- Comprehensive documentation explaining the business scenario
- Complete test coverage with realistic test cases
- Production-ready error handling and logging
- Clear API design following Elixir conventions

When adding new examples, follow the established patterns in `approval_workflow` for consistency and quality.

