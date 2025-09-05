# Statifier Examples

This directory contains practical examples demonstrating how to use Statifier for real-world applications.

## Getting Started

```bash
# Install dependencies
cd examples
mix deps.get

# Run all tests
mix examples.test

# List available examples
mix examples.run list

# Run a specific example
mix examples.run approval_workflow
```

## Available Examples

### 1. Approval Workflow (`approval_workflow/`)

A complete purchase order approval workflow demonstrating:

- **GenServer-based state machines** for long-running processes
- **Business logic callbacks** for state transitions and actions  
- **Conditional routing** based on purchase order amounts
- **Data model management** with SCXML assignments
- **Comprehensive testing** with realistic scenarios

**Key Features:**

- Small orders (≤ $5,000) → Manager approval
- Large orders (> $5,000) → Executive approval
- Rejection handling with reasons
- State persistence and logging

## Architecture

Each example follows this structure:

```
example_name/
├── README.md                    # Example-specific documentation  
├── scxml/                      # SCXML state machine definitions
│   └── *.xml
├── lib/                        # Elixir implementation
│   ├── *_machine.ex           # Main StateMachine module
│   └── *.ex                   # Supporting modules
├── test/                       # Comprehensive tests
│   └── *_test.exs
└── examples/                   # Demo scripts
    └── demo.exs
```

## Dependencies

- **Statifier**: State machine library (local path dependency)
- **Jason**: JSON encoding/decoding for data serialization
- **Logger**: Built-in logging for state transitions and business logic

## Testing

Examples include comprehensive test suites:

```bash
# Run all example tests
mix examples.test

# Run specific example tests
cd approval_workflow && mix test
```

All tests are tagged with `:example` for easy filtering.

## Development

### Adding New Examples

1. Create directory structure following the pattern above
2. Implement your StateMachine module using `use Statifier.StateMachine`
3. Create comprehensive tests tagged with `:example`  
4. Add demo script in `examples/demo.exs`
5. Update CLI in `lib/examples/cli.ex`
6. Document in README files

### Testing Philosophy

Examples serve as:

- **Integration tests** for Statifier features
- **Documentation** through working code
- **Templates** for users building similar applications

Each example should be production-ready with error handling, logging, and comprehensive test coverage.
