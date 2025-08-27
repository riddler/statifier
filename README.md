# Statifier - SCXML State Machines for Elixir

[![CI](https://github.com/riddler/statifier/workflows/CI/badge.svg?branch=main)](https://github.com/riddler/statifier/actions)
[![Coverage](https://codecov.io/gh/riddler/statifier/branch/main/graph/badge.svg)](https://codecov.io/gh/riddler/statifier)

An Elixir implementation of SCXML (State Chart XML) state charts with a focus on W3C compliance.

## Features

- ✅ **Complete SCXML Parser** - Converts XML documents to structured data with precise location tracking
- ✅ **State Chart Interpreter** - Runtime engine for executing SCXML state charts  
- ✅ **Modular Validation** - Document validation with focused sub-validators for maintainability
- ✅ **Compound States** - Support for hierarchical states with automatic initial child entry
- ✅ **Initial State Elements** - Full support for `<initial>` elements with transitions (W3C compliant)
- ✅ **Parallel States** - Support for concurrent state regions with simultaneous execution
- ✅ **Eventless Transitions** - Automatic transitions without event attributes (W3C compliant)
- ✅ **Conditional Transitions** - Full support for `cond` attributes with expression evaluation
- ✅ **Assign Elements** - Complete `<assign>` element support with location-based assignment and nested property access
- ✅ **Value Evaluation** - Non-boolean expression evaluation using Predicator v3.0 for actual data values
- ✅ **Data Model Integration** - StateChart data model with dynamic variable assignment and persistence
- ✅ **O(1) Performance** - Optimized state and transition lookups via Maps
- ✅ **Event Processing** - Internal and external event queues per SCXML specification
- ✅ **Parse → Validate → Optimize Architecture** - Clean separation of concerns
- ✅ **Feature Detection** - Automatic SCXML feature detection for test validation
- ✅ **Regression Testing** - Automated tracking of passing tests to prevent regressions
- ✅ **Git Hooks** - Pre-push validation workflow to catch issues early
- ✅ **Test Infrastructure** - Compatible with SCION and W3C test suites
- ✅ **Code Quality** - Full Credo compliance with proper module aliasing

## Current Status

### Working Features

- ✅ **Basic state transitions** and event-driven changes
- ✅ **Hierarchical states** with optimized O(1) state lookup and automatic initial child entry  
- ✅ **Initial state elements** - Full `<initial>` element support with transitions and comprehensive validation
- ✅ **Parallel states** with concurrent execution of multiple regions and proper cross-boundary exit semantics
- ✅ **Eventless transitions** - Automatic transitions without event attributes (also called NULL transitions in SCXML spec), with cycle detection and microstep processing
- ✅ **Conditional transitions** - Full `cond` attribute support with Predicator v3.0 expression evaluation and SCXML `In()` function
- ✅ **Assign elements** - Complete `<assign>` element support with location-based assignment, nested property access, and mixed notation
- ✅ **Value evaluation system** - Statifier.ValueEvaluator module for non-boolean expression evaluation and data model operations
- ✅ **Enhanced expression evaluation** - Predicator v3.0 integration with deep property access and type-safe operations
- ✅ **Transition conflict resolution** - Child state transitions take priority over ancestor transitions per W3C specification
- ✅ **SCXML-compliant processing** - Proper microstep/macrostep execution model with exit set computation and LCCA algorithms
- ✅ **Modular validation** - Refactored from 386-line monolith into focused sub-validators
- ✅ **Feature detection** - Automatic SCXML feature detection prevents false positive test results
- ✅ **SAX-based XML parsing** with accurate location tracking for error reporting
- ✅ **Performance optimizations** - O(1) state/transition lookups, optimized active configuration
- ✅ **Source field optimization** - Transitions include source state for faster event processing

### Planned Features

- History states (`<history>`)
- Internal and targetless transitions
- More executable content (`<script>`, `<send>`, etc.) - `<assign>` now supported!
- Enhanced datamodel support with more expression functions
- Enhanced validation for complex SCXML constructs

## Recent Completions

### **✅ SCXML-Compliant Processing Engine**

- **`Microstep/Macrostep Execution`** - Implements SCXML event processing model with microstep (single transition set execution) and macrostep (series of microsteps until stable)
- **`Eventless Transitions`** - Transitions without event attributes (called NULL transitions in SCXML spec) that fire automatically upon state entry
- **`Exit Set Computation`** - Implements W3C SCXML exit set calculation algorithm for determining which states to exit during transitions
- **`LCCA Algorithm`** - Full Least Common Compound Ancestor computation for accurate transition conflict resolution and exit set calculation
- **`Cycle Detection`** - Prevents infinite loops with configurable iteration limits (100 iterations default)
- **`Parallel Region Preservation`** - Proper SCXML exit semantics for transitions within and across parallel regions
- **`Optimal Transition Set`** - SCXML-compliant transition conflict resolution where child state transitions take priority over ancestors
- **`Test Coverage`** - 18+ comprehensive test scenarios covering all eventless transition patterns, LCCA edge cases, and complex hierarchies

### **✅ Enhanced Parallel State Support**

- **`Cross-Parallel Boundaries`** - Proper exit semantics when transitions leave parallel regions
- **`Sibling State Management`** - Automatic exit of parallel siblings when transitions exit their shared parent  
- **`Self-Transitions`** - Transitions within parallel regions preserve unaffected parallel regions
- **`SCION Compatibility`** - All 4 `cond_js` tests now pass, 6 parallel interrupt tests fixed
- **`Regression Prevention`** - 62 regression tests now validate all critical functionality

### **✅ Feature-Based Test Validation System**

- **`Statifier.FeatureDetector`** - Analyzes SCXML documents to detect used features
- **Feature validation** - Tests fail when they depend on unsupported features  
- **False positive prevention** - No more "passing" tests that silently ignore unsupported features
- **Capability tracking** - Clear visibility into which SCXML features are supported

### **✅ Modular Validator Architecture**

- **`Statifier.Validator`** - Main orchestrator (from 386-line monolith)
- **`Statifier.Validator.StateValidator`** - State ID validation
- **`Statifier.Validator.TransitionValidator`** - Transition target validation  
- **`Statifier.Validator.InitialStateValidator`** - All initial state constraints
- **`Statifier.Validator.ReachabilityAnalyzer`** - State reachability analysis
- **`Statifier.Validator.Utils`** - Shared utilities

### **✅ Initial State Elements**

- **Parser support** - `<initial>` elements with `<transition>` children
- **Interpreter logic** - Proper initial state entry via initial elements
- **Comprehensive validation** - Conflict detection, target validation, structure validation
- **Feature detection** - Automatic detection of initial element usage

## Future Extensions

The next major areas for development focus on expanding SCXML feature support:

### **High Priority Features**

- **Executable Content** - `<script>` elements (`<onentry>`, `<onexit>`, `<assign>` now supported!)
- **Datamodel Support** - `<data>` elements with expression evaluation
- **History States** - Shallow and deep history state support

### **Medium Priority Features**  

- **Internal Transitions** - `type="internal"` transition support
- **Targetless Transitions** - Transitions without target for pure actions
- **Enhanced Error Handling** - Better error messages with source locations
- **Performance Benchmarking** - Establish performance baselines and optimize hot paths

## Installation

Add `statifier` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:statifier, "~> 1.1"}
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

{:ok, document} = Statifier.parse(xml)

# Initialize state chart
{:ok, state_chart} = Statifier.interpret(document)

# Check active states
active_states = Statifier.Interpreter.active_states(state_chart)
# Returns: MapSet.new(["start"])

# Send event
event = Statifier.Event.new("go")
{:ok, new_state_chart} = Statifier.Interpreter.send_event(state_chart, event)

# Check new active states
active_states = Statifier.Interpreter.active_states(new_state_chart)
# Returns: MapSet.new(["end"])
```

### Eventless Transitions Example

```elixir
# Automatic transitions without events fire immediately
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
  <state id="start">
    <transition target="processing"/>  <!-- No event - fires automatically -->
  </state>
  <state id="processing">
    <transition target="done" cond="ready == true"/>  <!-- Conditional eventless -->
  </state>
  <state id="done"/>
</scxml>
"""

{:ok, document} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.interpret(document)

# Eventless transitions processed automatically during initialization
active_states = Statifier.Interpreter.active_states(state_chart)
# Returns: MapSet.new(["processing"]) - automatically moved from start
```

### Parallel States Example

```elixir
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
  <parallel id="app">
    <state id="ui" initial="idle">
      <state id="idle">
        <transition event="click" target="busy"/>
      </state>
      <state id="busy">
        <transition event="done" target="idle"/>
      </state>
    </state>
    <state id="network" initial="offline">
      <state id="offline">
        <transition event="connect" target="online"/>
      </state>
      <state id="online"/>
    </state>
  </parallel>
</scxml>
"""

{:ok, document} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.interpret(document)

# Both parallel regions active simultaneously
active_states = Statifier.Interpreter.active_states(state_chart)
# Returns: MapSet.new(["idle", "offline"])
```

### Document Validation

```elixir
{:ok, document} = Statifier.parse(xml)

case Statifier.validate(document) do
  {:ok, optimized_document, warnings} -> 
    # Document is valid and optimized, warnings are non-fatal
    IO.puts("Valid document with #{length(warnings)} warnings")
    # optimized_document now has O(1) lookup maps built
  {:error, errors, warnings} ->
    # Document has validation errors
    IO.puts("Validation failed with #{length(errors)} errors")
end
```

### Assign Elements Example

```elixir
# SCXML with assign elements for dynamic data manipulation
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
  <state id="start">
    <onentry>
      <assign location="userName" expr="'John Doe'"/>
      <assign location="counter" expr="42"/>
      <assign location="user.profile.name" expr="'Jane Smith'"/>
      <assign location="users['admin'].active" expr="true"/>
    </onentry>
    <transition target="working"/>
  </state>
  
  <state id="working">
    <onentry>
      <assign location="counter" expr="counter + 1"/>
      <assign location="status" expr="'processing'"/>
    </onentry>
    <onexit>
      <assign location="status" expr="'completed'"/>
    </onexit>
    <transition event="finish" target="done"/>
  </state>
  
  <final id="done"/>
</scxml>
"""

{:ok, document} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.interpret(document)

# Check the data model after onentry execution
data_model = state_chart.data_model
# Returns: %{
#   "userName" => "John Doe",
#   "counter" => 43,  # incremented to 43 in working state
#   "user" => %{"profile" => %{"name" => "Jane Smith"}},
#   "users" => %{"admin" => %{"active" => true}},
#   "status" => "processing"
# }
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
mix format              # Auto-fix formatting
mix test.regression     # Run critical regression tests (22 tests)
mix credo --strict      # Static code analysis
mix dialyzer           # Type checking
```

### Regression Testing

The project uses automated regression testing to prevent breaking existing functionality:

```bash
# Run only tests that should always pass (63 tests)
mix test.regression

# Check which tests are currently passing to update regression suite
mix test.baseline

# Install git hooks for automated validation
./scripts/setup-git-hooks.sh
```

The regression suite tracks:

- **Internal tests**: All `test/statifier/**/*_test.exs` files (supports wildcards) - includes edge case coverage tests
- **SCION tests**: 8 known passing tests (basic + hierarchy + parallel + conditional)
- **W3C tests**: Currently none passing

### Running Tests

```bash
# All internal tests (excludes SCION/W3C by default)
mix test

# All tests including SCION and W3C test suites
mix test --include scion --include scxml_w3

# Only regression tests (63 critical tests)
mix test.regression

# With coverage reporting
mix coveralls

# Specific test categories
mix test --include scion test/scion_tests/basic/
mix test test/statifier/parser/scxml_test.exs
```

## Architecture

### Core Components

- **`Statifier.Parser.SCXML`** - SAX-based XML parser with location tracking (parse phase)
- **`Statifier.Validator`** - Modular validation orchestrator with focused sub-validators (validate + optimize phases)
- **`Statifier.FeatureDetector`** - SCXML feature detection for test validation and capability tracking
- **`Statifier.Interpreter`** - Synchronous state chart interpreter with compound state support
- **`Statifier.StateChart`** - Runtime container with event queues
- **`Statifier.Configuration`** - Active state management (leaf states only)
- **`Statifier.Event`** - Event representation with origin tracking

### Data Structures

- **`Statifier.Document`** - Root SCXML document with states, metadata, and O(1) lookup maps
- **`Statifier.State`** - Individual states with transitions and hierarchical nesting support
- **`Statifier.Transition`** - State transitions with events and targets
- **`Statifier.Data`** - Datamodel elements with expressions

### Architecture Flow

```elixir
# 1. Parse: XML → Document structure
{:ok, document} = Statifier.parse(xml)

# 2. Validate: Check semantics + optimize with lookup maps  
{:ok, optimized_document, warnings} = Statifier.validate(document)

# 3. Interpret: Run state chart with optimized lookups
{:ok, state_chart} = Statifier.interpret(optimized_document)
```

## Performance Optimizations

The implementation includes several key optimizations for production use:

### **O(1) State and Transition Lookups**

- **State Lookup Map**: `%{state_id => state}` for instant state access
- **Transition Lookup Map**: `%{state_id => [transitions]}` for fast transition queries  
- **Built During Validation**: Lookup maps only created for valid documents
- **Memory Efficient**: Uses existing document structure, no duplication

### **Compound and Parallel State Entry**

```elixir
# Automatic hierarchical entry
{:ok, state_chart} = Statifier.interpret(document)
active_states = Statifier.Interpreter.active_states(state_chart)
# Returns only leaf states (compound/parallel states entered automatically)

# Fast ancestor computation when needed
ancestors = Statifier.Interpreter.active_ancestors(state_chart) 
# O(1) state lookups + O(d) ancestor traversal

# Parallel states enter ALL child regions simultaneously
# Compound states enter initial child recursively
```

### **Parse → Validate → Optimize Flow**

- **Separation of Concerns**: Parser focuses on structure, validator on semantics
- **Conditional Optimization**: Only builds lookup maps for valid documents
- **Future-Proof**: Supports additional parsers (JSON, YAML) with same validation

**Performance Impact:**

- O(1) vs O(n) state lookups during interpretation
- O(1) vs O(n) transition queries for event processing  
- Source field optimization eliminates expensive lookups during event processing
- Critical for responsive event processing in complex state charts

## Regression Testing System

The project includes a sophisticated regression testing system to ensure stability:

### **Test Registry** (`test/passing_tests.json`)

```json
{
  "internal_tests": ["test/statifier_test.exs", "test/statifier/**/*_test.exs"],
  "scion_tests": ["test/scion_tests/basic/basic0_test.exs", ...],
  "w3c_tests": []
}
```

### **Wildcard Support**

- Supports glob patterns like `test/statifier/**/*_test.exs`
- Automatically expands to all matching test files
- Maintains clean, maintainable test registry

### **CI Integration**

- Regression tests run before full test suite in CI
- Prevents merging code that breaks core functionality
- Fast feedback loop (63 tests vs 444 total tests)

### **Local Development**

```bash
# Check current regression status
mix test.regression

# Update regression baseline after adding features
mix test.baseline
# Manually add newly passing tests to test/passing_tests.json

# Pre-push hook automatically runs regression tests
git push origin feature-branch
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Install git hooks: `./scripts/setup-git-hooks.sh`
4. Make your changes following the code quality workflow:
   - `mix format` (auto-fix formatting)
   - Add tests for new functionality
   - `mix test.regression` (ensure no regressions)
   - `mix credo --strict` (static analysis)
   - `mix dialyzer` (type checking)
5. Update regression tests if you fix failing SCION/W3C tests:
   - Run `mix test.baseline` to see current status
   - Add newly passing tests to `test/passing_tests.json`
6. Ensure all CI checks pass
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (pre-push hook will run automatically)
9. Open a Pull Request

### Code Style

- All code is formatted with `mix format`
- Static analysis with Credo (strict mode)
- Type checking with Dialyzer
- Comprehensive test coverage (95%+ maintained)
- Detailed documentation with `@moduledoc` and `@doc`
- Pattern matching preferred over multiple assertions in tests
- Git pre-push hook enforces validation workflow automatically
- Regression tests ensure core functionality never breaks

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [W3C SCXML Specification](https://www.w3.org/TR/scxml/) - Official specification
- [SCION Test Suite](https://github.com/jbeard4/SCION) - Comprehensive test cases
- [ex_statechart](https://github.com/camshaft/ex_statechart) - Reference implementation

