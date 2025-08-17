# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Code Verification Workflow:**
When verifying code changes, always follow this sequence:
1. `mix format` - Auto-fix formatting issues (trailing whitespace, final newlines, etc.)
2. `mix coveralls` - Ensure functionality and maintain at least 90% test coverage
3. `mix credo --strict` - Run static code analysis only after tests pass
4. `mix dialyzer` - Run Dialyzer static analysis for type checking

**Testing:**
- `mix coveralls` - Run all tests with coverage reporting (ensure at least 90% coverage)
- `mix coveralls.detail` - Run tests with detailed coverage report showing uncovered lines
- `mix test` - Run all tests without coverage
- `mix test test/sc/location_test.exs` - Run location tracking tests
- `mix test test/sc/parser/scxml_test.exs` - Run specific SCXML parser tests

**Development:**
- `mix deps.get` - Install dependencies
- `mix compile` - Compile the project
- `mix docs` - Generate documentation
- `mix format` - Format code according to Elixir standards (run first for code verification)
- `mix format --check-formatted` - Check if code is properly formatted
- `mix credo --strict` - Run static code analysis with strict mode (run after tests pass)
- `mix dialyzer` - Run Dialyzer for static type analysis (run last in verification workflow)

## Architecture

This is an Elixir implementation of SCXML (State Chart XML) state machines with a focus on W3C compliance.

The State Chart reference XML is here: https://www.w3.org/TR/scxml/

This project uses Elixir Structs for the data structures, and MapSets for sets.

Also use this initial Elixir implementation as reference: https://github.com/camshaft/ex_statechart

## Core Components

### Data Structures
- **`SC.Document`** - Root SCXML document structure with attributes like `name`, `initial`, `datamodel`, `version`, `xmlns`, plus collections of `states` and `datamodel_elements`
- **`SC.State`** - Individual state with `id`, optional `initial` state, nested `states` list, and `transitions` list
- **`SC.Transition`** - State transitions with optional `event`, `target`, and `cond` attributes
- **`SC.DataElement`** - Datamodel elements with required `id` and optional `expr` and `src` attributes

### Parsers
- **`SC.Parser.SCXML`** - Main SCXML parser using Saxy SAX parser for accurate location tracking
  - Parses XML strings into `SC.Document` structs with precise source location information
  - Event-driven SAX parsing for better memory efficiency and location tracking
  - Handles namespace declarations and XML attributes correctly
  - Supports nested states and hierarchical structures
  - Converts empty XML attributes to `nil` for cleaner data representation
  - Returns `{:ok, document}` or `{:error, reason}` tuples
- **`SC.Parser.SCXML.Handler`** - SAX event handler for SCXML parsing
  - Implements `Saxy.Handler` behavior for processing XML events
  - Tracks element occurrences and position information during parsing
  - Manages element stack for proper hierarchical document construction
- **`SC.Parser.SCXML.ElementBuilder`** - Builds SCXML elements from SAX events
- **`SC.Parser.SCXML.LocationTracker`** - Tracks precise source locations for elements and attributes
- **`SC.Parser.SCXML.StateStack`** - Manages parsing state stack for hierarchical document construction

### Interpreter and Runtime
- **`SC.Interpreter`** - Core SCXML interpreter with synchronous API
  - Initializes state charts from validated documents
  - Processes events and manages state transitions
  - Returns active state configurations
  - Provides `{:ok, result}` or `{:error, reason}` responses
- **`SC.StateChart`** - Runtime container for SCXML state machines
  - Combines document, configuration, and event queues
  - Maintains internal and external event queues per SCXML specification
- **`SC.Configuration`** - Active state configuration management
  - Stores only leaf states for efficient memory usage
  - Computes ancestor states dynamically from document hierarchy
  - Uses MapSets for fast state membership testing
- **`SC.Event`** - Event representation with internal/external origins
  - Supports event data and origin tracking
  - Used for state machine event processing
- **`SC.Document.Validator`** - Document validation and consistency checking
  - Validates structural correctness and semantic consistency
  - Includes finalize callback for whole-document validations
  - Catches issues like invalid references, unreachable states, malformed hierarchies

### Test Infrastructure
- **`SC.Case`** - Test case template module for SCXML testing
  - Provides `test_scxml/4` function for testing state machine behavior
  - Uses SC.Interpreter for document initialization and event processing
  - Supports initial configuration verification and event sequence testing
  - Used by both SCION and W3C test suites

### Location Tracking
All parsed SCXML elements include precise source location information for validation error reporting:

- **Element locations**: Each parsed element (`SC.Document`, `SC.State`, `SC.Transition`, `SC.DataElement`) includes a `source_location` field with line/column information
- **Attribute locations**: Individual attributes have dedicated location fields (e.g., `name_location`, `id_location`, `event_location`) for precise error reporting
- **Multiline support**: Accurately tracks locations for both single-line and multiline XML element definitions
- **SAX-based tracking**: Uses Saxy's event-driven parsing to maintain position information throughout the parsing process

## Dependencies

- **`saxy`** (~> 1.6) - Fast, memory-efficient SAX XML parser with position tracking support

## Development Dependencies

- **`credo`** (~> 1.7) - Static code analysis tool for code quality and consistency
- **`dialyxir`** (~> 1.4) - Dialyzer wrapper for static type analysis and error detection

## Tests

This project includes comprehensive test coverage:

### SCION Test Suite (`test/scion_tests/`)
- 127+ test files from the SCION project
- Module naming: `SCIONTest.Category.TestNameTest` (e.g., `SCIONTest.ActionSend.Send1Test`)
- Uses `SC.Case` for test infrastructure
- Tests cover basic state machines, transitions, parallel states, history, etc.

### W3C SCXML Test Suite (`test/scxml_tests/`)
- 59+ test files from W3C SCXML conformance tests
- Module naming: `Test.StateChart.W3.Category.TestName` (e.g., `Test.StateChart.W3.Events.Test396`)
- Uses `SC.Case` for test infrastructure
- Organized by SCXML specification sections (mandatory tests)

### Parser Tests (`test/sc/parser/scxml_test.exs`)
- Unit tests for `SC.Parser.SCXML`
- Tests parsing of simple documents, transitions, datamodels, nested states
- Validates error handling for invalid XML
- Ensures proper attribute handling (nil for empty values)

### Location Tracking Tests (`test/sc/location_test.exs`)
- Tests for precise source location tracking in SCXML documents
- Validates line number accuracy for elements and attributes
- Tests both single-line and multiline XML element definitions
- Ensures proper location tracking for nested elements and datamodel elements

## Code Style

- All generated files have no trailing whitespace
- Code is formatted using `mix format`
- Static code analysis with `mix credo --strict` - all issues resolved
- Type specs (`@spec`) are provided for all public functions
- Comprehensive documentation with `@moduledoc` and `@doc`
- Consistent naming for unused variables (meaningful names with `_` prefix)

## XML Format

Test files use triple-quote multiline strings for XML content:

```elixir
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
    <state id="a"/>
</scxml>
"""
```

XML content within triple quotes uses 4-space base indentation.

## SCION Test Results

**Current Status:** 107/225 tests passing (47.6% pass rate)

**Working Features:**
- ✅ Basic state transitions (basic1, basic2 tests pass)
- ✅ Simple hierarchical states  
- ✅ Event-driven state changes
- ✅ Initial state configuration
- ✅ Document validation and error reporting

**Main Failure Categories:**
- **Document parsing failures**: Complex SCXML with parallel states, history states, executable content
- **Validation too strict**: Rejecting valid but complex SCXML documents  
- **Missing SCXML features**: Parallel states, conditional transitions, targetless transitions, internal transitions
- **Missing executable content**: `<script>`, `<assign>`, `<send>`, `<raise>`, `<onentry>`, `<onexit>`
- **Incomplete hierarchy handling**: Initial state resolution for compound states

## Implementation Status

✅ **Completed:**
- Core data structures (Document, State, Transition, DataElement) with location tracking
- SCXML parser using Saxy SAX parser for accurate position tracking
- Complete interpreter infrastructure (Interpreter, StateChart, Configuration, Event, Validator)  
- Comprehensive test suite integration (SCION + W3C)
- Test infrastructure with SC.Case module using interpreter
- XML parsing with namespace support and precise source location tracking
- Error handling for malformed XML
- Location tracking for elements and attributes (line numbers for validation errors)
- Support for both single-line and multiline XML element definitions
- Basic state machine interpretation with event processing
- Document validation with finalize callback for whole-document checks
- Active state tracking with hierarchical ancestor computation

🚧 **Future Extensions:**
- Parallel states (`<parallel>`) - major gap in current implementation
- History states (`<history>`) - missing from parser and interpreter  
- Conditional transitions with `cond` attribute evaluation
- Internal transitions (`type="internal"`) and targetless transitions
- Executable content elements (`<onentry>`, `<onexit>`, `<raise>`, `<assign>`, `<script>`, `<send>`)
- Initial state resolution for compound states without explicit initial attribute
- Expression evaluation and datamodel support
- Enhanced validation for complex SCXML constructs

The implementation follows the W3C SCXML specification closely and includes comprehensive test coverage from both W3C and SCION test suites. The current interpreter provides a solid foundation for basic SCXML functionality with clear areas identified for future enhancement.

- Always refer to state machines as state charts