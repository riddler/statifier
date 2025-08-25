# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Local Validation Workflow:**
When verifying code changes, always follow this sequence (also automated via pre-push git hook):

1. `mix format` - Auto-fix formatting issues (trailing whitespace, final newlines, etc.)
2. `mix test --cover` - Ensure functionality and maintain 95%+ test coverage  
3. `mix credo --strict` - Run static code analysis only after tests pass
4. `mix dialyzer` - Run Dialyzer static analysis for type checking

**Git Hooks:**

- `./scripts/setup-git-hooks.sh` - Install pre-push hook for validation pipeline
- Pre-push hook automatically runs the validation workflow to catch issues before CI
- Located at `.git/hooks/pre-push` (executable)
- Blocks push if any validation step fails

**Regression Testing:**

- `test/passing_tests.json` - Registry of tests that should always pass
- Tracks internal tests, SCION tests, and W3C tests separately
- Updated manually when new tests start passing consistently
- Used by CI pipeline to catch regressions early

**Testing:**

- `mix test` - Run all internal tests (excludes SCION/W3C by default) - 444 tests
- `mix test --include scion --include scxml_w3` - Run all tests including SCION and W3C tests
- `mix test.regression` - Run regression tests that should always pass - 63 tests (critical functionality)
- `mix test.baseline` - Check which tests are currently passing (for updating regression suite)
- `mix test --cover` - Run all tests with coverage reporting (maintain 90%+ coverage - currently 92.3%)
- `mix coveralls` - Alternative coverage command
- `mix coveralls.detail` - Run tests with detailed coverage report showing uncovered lines
- `mix test test/sc/location_test.exs` - Run location tracking tests
- `mix test test/sc/parser/scxml_test.exs` - Run specific SCXML parser tests (uses pattern matching)
- `mix test test/sc/interpreter/compound_state_test.exs` - Run compound state tests
- `mix test test/sc/interpreter/eventless_transitions_test.exs` - Run eventless transition tests

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

The State Chart reference XML is here: <https://www.w3.org/TR/scxml/>

This project uses Elixir Structs for the data structures, and MapSets for sets.

Also use this initial Elixir implementation as reference: <https://github.com/camshaft/ex_statechart>

## Core Components

### Data Structures

- **`SC.Document`** - Root SCXML document structure with:
  - Attributes: `name`, `initial`, `datamodel`, `version`, `xmlns`
  - Collections: `states`, `datamodel_elements`  
  - O(1) Lookup maps: `state_lookup` (id → state), `transitions_by_source` (id → [transitions])
  - Built via `Document.build_lookup_maps/1` during validation phase
- **`SC.State`** - Individual state with `id`, optional `initial` state, nested `states` list, and `transitions` list
- **`SC.Transition`** - State transitions with optional `event`, `target`, and `cond` attributes
- **`SC.DataElement`** - Datamodel elements with required `id` and optional `expr` and `src` attributes

### Parsers (Parse Phase)

- **`SC.Parser.SCXML`** - Main SCXML parser using Saxy SAX parser for accurate location tracking
  - Parses XML strings into `SC.Document` structs with precise source location information
  - Event-driven SAX parsing for better memory efficiency and location tracking
  - Handles namespace declarations and XML attributes correctly
  - Supports nested states and hierarchical structures
  - Converts empty XML attributes to `nil` for cleaner data representation
  - Returns `{:ok, document}` or `{:error, reason}` tuples
  - **Pure parsing only** - does not build optimization structures
- **`SC.Parser.SCXML.Handler`** - SAX event handler for SCXML parsing
  - Implements `Saxy.Handler` behavior for processing XML events
  - Tracks element occurrences and position information during parsing
  - Manages element stack for proper hierarchical document construction
- **`SC.Parser.SCXML.ElementBuilder`** - Builds SCXML elements from SAX events
- **`SC.Parser.SCXML.LocationTracker`** - Tracks precise source locations for elements and attributes
- **`SC.Parser.SCXML.StateStack`** - Manages parsing state stack for hierarchical document construction

### Validation and Optimization (Validate + Optimize Phases)

- **`SC.Validator`** - Main validation orchestrator
  - **Modular architecture**: Split into focused sub-validators for maintainability
  - **Validation**: Structural correctness, semantic consistency, reference validation
  - **Optimization**: Builds O(1) lookup maps via `finalize/2` for valid documents only
  - Returns `{:ok, optimized_document, warnings}` or `{:error, errors, warnings}`
  - **Clean architecture**: Only optimizes documents that pass validation
- **`SC.Validator.StateValidator`** - State ID uniqueness and validation
- **`SC.Validator.TransitionValidator`** - Transition target validation
- **`SC.Validator.InitialStateValidator`** - All initial state constraints (attributes, elements, conflicts)
- **`SC.Validator.ReachabilityAnalyzer`** - State reachability graph analysis  
- **`SC.Validator.Utils`** - Shared utilities across validators

### Interpreter and Runtime  

- **`SC.Interpreter`** - Core SCXML interpreter with W3C-compliant processing model
  - **Microstep/Macrostep Execution**: Implements SCXML event processing model where microsteps (single transition set execution) are processed until stable macrostep completion
  - **Exit Set Computation**: Uses W3C SCXML exit set calculation algorithm for determining which states to exit during transitions
  - **LCCA Algorithm**: Full Least Common Compound Ancestor computation for accurate transition conflict resolution and exit set calculation
  - **Eventless Transitions**: Automatic transitions without event attributes (also called NULL transitions in SCXML spec)
  - **Optimal Transition Set**: SCXML-compliant transition conflict resolution where child state transitions take priority over ancestors
  - **Compound state support**: Automatically enters initial child states recursively
  - **Parallel state support**: Proper concurrent execution with cross-boundary exit semantics and parallel region preservation
  - **Conditional transitions**: Full `cond` attribute support with Predicator v3.0 expression evaluation and SCXML `In()` function
  - **Assign action support**: Complete `<assign>` element execution with data model integration
  - **Cycle Detection**: Prevents infinite loops in eventless transitions with configurable iteration limits (100 iterations default)
  - **O(1 lookups**: Uses `Document.find_state/2` and `Document.get_transitions_from_state/2`
  - Separates `active_states()` (leaf only) from `active_ancestors()` (includes parents)
  - Provides `{:ok, result}` or `{:error, reason}` responses
- **`SC.StateChart`** - Runtime container for SCXML state machines
  - Combines document, configuration, event queues, and data model
  - Maintains internal and external event queues per SCXML specification
  - **Data model storage**: Persistent variable storage with `data_model` field
  - **Current event context**: Tracks current event for expression evaluation
- **`SC.Configuration`** - Active state configuration management
  - Stores only leaf states for efficient memory usage
  - Computes ancestor states dynamically via `active_ancestors/2` using O(1) document lookups
  - Uses MapSets for fast state membership testing
  - Optimized MapSet operations (direct construction vs incremental building)
- **`SC.Event`** - Event representation with internal/external origins
  - Supports event data and origin tracking
  - Used for state machine event processing

### Expression Evaluation and Data Model

- **`SC.ValueEvaluator`** - Comprehensive value evaluation system for SCXML expressions
  - **Expression compilation**: `compile_expression/1` for reusable predicator compilation
  - **Value evaluation**: `evaluate_value/2` extracts actual values (not just boolean results)
  - **Location path resolution**: `resolve_location/1,2` validates assignment paths using predicator v3.0's `context_location`
  - **Safe assignment operations**: `assign_value/3` performs type-safe nested data model updates
  - **Integrated assignment**: `evaluate_and_assign/3` combines evaluation and assignment
  - **SCXML context support**: Full integration with state machine context (events, configuration, datamodel)
  - **Nested property access**: Support for deep property access (`user.profile.settings.theme`)
  - **Mixed access patterns**: Combined bracket/dot notation (`users['john'].active`)
  - **Error handling**: Comprehensive error handling with detailed logging
- **`SC.ConditionEvaluator`** - Enhanced with predicator v3.0 integration
  - **Predicator v3.0**: Upgraded from v2.0 with enhanced nested property access capabilities
  - **SCXML functions**: Maintains `In()` function and SCXML-specific context building
  - **Type-safe operations**: Improved type coercion and graceful fallback for missing properties

### Actions and Executable Content

- **`SC.Actions.AssignAction`** - SCXML `<assign>` element implementation
  - **Location-based assignment**: Validates assignment paths using SC.ValueEvaluator
  - **Expression evaluation**: Uses SC.ValueEvaluator for complex expression processing
  - **Nested property assignment**: Supports deep assignment (`user.profile.name = "John"`)
  - **Mixed notation support**: Handles both dot and bracket notation in assignments
  - **Context integration**: Access to current event data and state configuration
  - **Error recovery**: Graceful error handling with logging, continues execution on failures
- **`SC.Actions.LogAction`** - SCXML `<log>` element implementation for debugging
- **`SC.Actions.RaiseAction`** - SCXML `<raise>` element implementation for internal events
- **`SC.Actions.ActionExecutor`** - Centralized action execution system
  - **Phase tracking**: Executes actions during appropriate state entry/exit phases
  - **Mixed action support**: Handles log, raise, assign, and future action types
  - **StateChart integration**: Actions can modify state chart data model and event queues

### Architecture Flow

The implementation follows a clean **Parse → Validate → Optimize** architecture:

```elixir
# 1. Parse Phase: XML → Document structure
{:ok, document} = SC.Parser.SCXML.parse(xml_string)

# 2. Validate + Optimize Phase: Check semantics + build lookup maps
{:ok, optimized_document, warnings} = SC.Validator.validate(document)

# 3. Interpret Phase: Use optimized document for runtime
{:ok, state_chart} = SC.Interpreter.initialize(optimized_document)
```

**Benefits:**

- Parsers focus purely on structure (supports future JSON/YAML parsers)
- Validation catches semantic errors before optimization
- Only valid documents get expensive optimization treatment
- Clear separation of concerns across phases

### Feature Detection and Test Infrastructure

- **`SC.FeatureDetector`** - Detects SCXML features used in documents
  - Enables proper test validation by failing tests that depend on unsupported features
  - Prevents false positive test results from unsupported feature usage
  - Supports both XML string and parsed document analysis
  - Tracks feature support status (`:supported`, `:unsupported`, `:partial`)
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

- **`predicator`** (~> 3.0) - Safe condition and value evaluator with enhanced nested property access
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
- **Uses pattern matching** instead of multiple individual asserts for cleaner, more informative tests
- Tests parsing of simple documents, transitions, datamodels, nested states
- Validates error handling for invalid XML
- Ensures proper attribute handling (nil for empty values)

### Location Tracking Tests (`test/sc/location_test.exs`)

- Tests for precise source location tracking in SCXML documents
- Validates line number accuracy for elements and attributes
- Tests both single-line and multiline XML element definitions
- Ensures proper location tracking for nested elements and datamodel elements

### Expression Evaluation Tests

- **`test/sc/value_evaluator_test.exs`** - Comprehensive tests for SC.ValueEvaluator module
  - Value evaluation, location resolution, assignment operations
  - Nested property access and mixed notation support
  - SCXML context integration and error handling
- **`test/sc/actions/assign_action_test.exs`** - Complete assign action functionality
  - Action creation, execution, and error handling
  - Data model integration and context evaluation
  - Mixed action execution and state chart modification
- **`test/sc/parser/assign_parsing_test.exs`** - SCXML assign element parsing
  - Assign element parsing in onentry/onexit contexts
  - Mixed action parsing (log, raise, assign together)
  - Complex expression and location parsing

## Code Style

- All generated files have no trailing whitespace
- Code is formatted using `mix format`
- Static code analysis with `mix credo --strict` - all issues resolved
- Type specs (`@spec`) are provided for all public functions
- Comprehensive documentation with `@moduledoc` and `@doc`
- Consistent naming for unused variables (meaningful names with `_` prefix)
- **Pattern matching preferred** over multiple individual assertions in tests
- Git pre-push hook enforces validation workflow automatically

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

**Current Status:** 34/127 tests passing (26.8% pass rate) - ✅ +4 with eventless transitions and SCXML-compliant processing

**Working Features:**

- ✅ Basic state transitions (basic1, basic2 tests pass)
- ✅ **Compound states** with automatic initial child entry
- ✅ **Initial state elements** (`<initial>` with transitions) - W3C compliant
- ✅ **Parallel states** with concurrent execution and proper exit semantics
- ✅ **SCXML-compliant processing** - Proper microstep/macrostep execution model with exit set computation and LCCA algorithms
- ✅ **Eventless transitions** - Automatic transitions without event attributes (also called NULL transitions in SCXML spec)
- ✅ **Conditional transitions** - Full `cond` attribute support with Predicator v3.0 expression evaluation and SCXML `In()` function
- ✅ **Assign elements** - Complete `<assign>` element support with location-based assignment and nested property access
- ✅ **Value evaluation** - Non-boolean expression evaluation using Predicator v3.0 for actual data values
- ✅ **Data model support** - StateChart data model integration with dynamic variable assignment
- ✅ **Optimal Transition Set** - SCXML-compliant transition conflict resolution where child state transitions take priority over ancestors
- ✅ Hierarchical states with O(1) optimized lookups
- ✅ Event-driven state changes
- ✅ Initial state configuration (both `initial="id"` attributes and `<initial>` elements)
- ✅ Document validation and error reporting
- ✅ **Parse → Validate → Optimize** architecture
- ✅ **Modular validator architecture** with focused sub-validators

**Main Failure Categories:**

- **Document parsing failures**: Complex SCXML with history states, executable content
- **Validation too strict**: Rejecting valid but complex SCXML documents  
- **Missing SCXML features**: Targetless transitions, internal transitions
- **Missing executable content**: `<script>`, `<send>` (assign, raise, onentry, onexit now supported)
- **Missing datamodel features**: Enhanced expression evaluation, additional functions

## Implementation Status

✅ **Completed:**

- Core data structures (Document, State, Transition, DataElement) with location tracking
- SCXML parser using Saxy SAX parser for accurate position tracking
- **Parse → Validate → Optimize architecture** with clean separation of concerns
- Complete interpreter infrastructure (Interpreter, StateChart, Configuration, Event, Validator)  
- **Compound state support** with automatic initial child entry recursion
- **Parallel state support** with concurrent execution and proper cross-boundary exit semantics
- **SCXML-compliant processing model** with proper microstep/macrostep execution, exit set computation, and LCCA algorithms
- **Eventless transitions** - Automatic transitions without event attributes (also called NULL transitions in SCXML spec)
- **Conditional transitions** - Full `cond` attribute support with Predicator v3.0 expression evaluation and SCXML `In()` function
- **Assign elements** - Complete `<assign>` element support with SC.ValueEvaluator and location-based assignment
- **Value evaluation system** - SC.ValueEvaluator module for non-boolean expression evaluation and data model operations
- **Enhanced expression evaluation** - Predicator v3.0 integration with nested property access and mixed notation support
- **Optimal Transition Set** - SCXML-compliant transition conflict resolution where child state transitions take priority over ancestors
- **Exit Set Computation** - W3C SCXML exit set calculation algorithm for proper state exit semantics
- **LCCA Algorithm** - Full Least Common Compound Ancestor computation for accurate transition conflict resolution
- **O(1 performance optimizations** via state and transition lookup maps
- Comprehensive test suite integration (SCION + W3C) - 556 tests, 85 regression tests, 92.9% coverage
- Test infrastructure with SC.Case module using interpreter
- **Pattern matching in tests** instead of multiple individual assertions
- XML parsing with namespace support and precise source location tracking
- Error handling for malformed XML
- Location tracking for elements and attributes (line numbers for validation errors)
- Support for both single-line and multiline XML element definitions
- State machine interpretation with event processing and optimized lookups
- Document validation with finalize callback building optimization structures
- Active state tracking with hierarchical ancestor computation using O(1) lookups
- **Git pre-push hook** for automated local validation workflow
- **Enhanced test coverage** - 92.3% overall coverage (exceeds 90% minimum), interpreter module at 83.0%
- **Initial state elements** (`<initial>` with `<transition>`) with comprehensive validation
- **Modular validator architecture** - refactored from 386-line monolith into focused modules
- **Full Credo compliance** - all code quality issues resolved

## SCXML Feature Implementation Roadmap

📋 **Comprehensive Implementation Plan Available**: See `documentation/SCXML_IMPLEMENTATION_PLAN.md` for detailed 3-phase roadmap to achieve 98%+ test coverage across 444 SCION and W3C tests.

### Current Implementation Status (Phase 0 - Complete)

✅ **Structural SCXML Features** - Complete W3C compliance for basic state machine functionality:

- Core state machine elements (states, transitions, parallel, initial)
- SCXML-compliant processing model (microstep/macrostep, exit sets, LCCA)
- Conditional transitions with expression evaluation
- Eventless/automatic transitions (NULL transitions)
- Feature detection and test validation infrastructure

**Current Test Coverage**: 294/444 tests passing (66.2%)

### Planned Implementation Phases

🚧 **Phase 1: Basic Executable Content (2-3 weeks)**
**Target**: Unlock 80-100 additional tests (30% improvement)

- **`<onentry>` / `<onexit>` actions** - Execute actions during state entry/exit
- **`<raise event="name"/>` elements** - Generate internal events  
- **`<log expr="message"/>` elements** - Debug logging support
- **Action execution framework** - Infrastructure for executable content

**Expected Outcome**: ~374 tests passing (84% coverage)

🚧 **Phase 2: Data Model & Expression Evaluation (4-6 weeks)**
**Target**: Unlock 50-70 additional tests (25% improvement)

- **`<datamodel>` / `<data>` elements** - Variable storage and initialization
- **`<assign location="var" expr="value"/>` elements** - Variable assignment
- **JavaScript expression engine** - Full ECMAScript expression support
- **Enhanced condition evaluation** - Access to datamodel variables

**Expected Outcome**: ~420 tests passing (95% coverage)

🚧 **Phase 3: Advanced Features (2-3 weeks)**
**Target**: Achieve comprehensive SCXML support (98%+ coverage)

- **`<history>` states** - Shallow and deep history state support
- **`<send>` elements** - External event sending with delays
- **`<script>` elements** - Inline JavaScript execution
- **Internal/targetless transitions** - Advanced transition behaviors

**Expected Outcome**: ~440+ tests passing (98%+ coverage)

### Implementation Architecture

The phased approach systematically adds SCXML features:

1. **Parser Extensions**: Add executable content parsing to existing SAX-based parser
2. **Interpreter Integration**: Extend microstep/macrostep processing with action execution  
3. **Data Model Layer**: Add variable storage and JavaScript expression evaluation
4. **Feature Detection Updates**: Maintain comprehensive feature tracking
5. **Test Coverage Validation**: Ensure each phase improves test coverage without regressions

### Success Metrics

- **Phase 1**: 370+ tests passing, all basic executable content working
- **Phase 2**: 415+ tests passing, full datamodel and expression support  
- **Phase 3**: 435+ tests passing, comprehensive SCXML implementation
- **Final Goal**: 98%+ test coverage, industry-leading SCXML compliance

The implementation plan transforms SC from a basic state machine library into a comprehensive, production-ready SCXML engine with industry-leading test coverage and W3C compliance.

- Always refer to state machines as state charts
- Always run 'mix format' after writing an Elixir file.
