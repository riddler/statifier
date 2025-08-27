# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### If/Else/ElseIf Conditional Action Support

- **`<if>` Action Support**: Full implementation of SCXML `<if>` elements with conditional execution
  - **`Statifier.Actions.IfAction` Struct**: Represents if/elseif/else conditional blocks
  - **Nested Action Execution**: Supports multiple actions within each conditional block
  - **Expression Evaluation**: Uses Statifier.Evaluator for condition evaluation
  - **ActionExecutor Integration**: Seamlessly integrates with existing action execution framework
  - **Complex Conditionals**: Support for if/elseif/else chains with proper precedence

- **Parser Extensions for Conditional Actions**: Extended SCXML parser to handle conditional elements
  - **If/ElseIf/Else Parsing**: Complete parsing support for conditional action blocks
  - **StateStack Integration**: Proper conditional block handling in parsing state stack
  - **Mixed Action Support**: Parse conditional actions alongside log/raise/assign actions
  - **Location Tracking**: Complete source location tracking for debugging conditional blocks

#### Test Coverage Improvements

- **90.8% Overall Coverage**: Comprehensive test coverage improvements through targeted edge case testing
  - **StateStack Coverage**: Improved from 72.7% to 95.8% (+23.1% - biggest impact module)
  - **ActionExecutor Edge Cases**: Added comprehensive error handling and edge case tests  
  - **Interpreter Coverage**: Added simple edge case tests avoiding duplication with existing functionality
  - **Handler Coverage**: Added unknown element handling and parsing edge case tests
  - **4 New Test Files**: Comprehensive coverage tests for critical modules

- **Enhanced LogAction**: Improved string evaluation and error handling
  - **Evaluator Integration**: Uses Statifier.Evaluator for consistent expression handling
  - **String Validation**: Proper Unicode string validation and safe logging
  - **Fallback Parsing**: Graceful fallback for quoted string parsing
  - **Error Recovery**: Continues execution even with invalid expressions

#### Architecture Improvements

- **Unified `Statifier.Evaluator` Module**: Consolidated `ConditionEvaluator` and `ValueEvaluator` into single module
  - **Single Entry Point**: One module for all expression evaluation (conditions and values)
  - **Improved Maintainability**: Eliminated code duplication between evaluator modules
  - **Future Extensibility**: Better prepared for pluggable datamodel architectures (ECMAScript, XPath)
  - **Consistent API**: Unified function signatures and error handling patterns

- **Enhanced `Statifier.Datamodel` Module**: Improved data model operations and separation of concerns
  - **`put_in_path/3` Function**: Moved from Evaluator to Datamodel for better architecture
  - **Improved Error Handling**: Returns `{:ok, result} | {:error, reason}` instead of raising exceptions
  - **Type Safety**: Proper `Datamodel.t()` typing throughout the codebase
  - **Data Model Operations**: Centralized location for all data model manipulation logic

- **Feature Detection Updates**: Enhanced SCXML feature tracking for better test validation
  - **Datamodel Support**: Marked `:datamodel` and `:data_elements` as `:supported` in feature registry
  - **Accurate Test Results**: Prevents false test failures from unsupported feature detection
  - **Better Compliance Tracking**: Improved visibility into SCXML feature implementation status

### Changed

#### Action Execution Architecture

- **ActionExecutor Delegation Pattern**: Improved action execution through proper delegation
  - **Public `execute_single_action/2`**: Made function public for IfAction integration
  - **Action Delegation**: ActionExecutor now properly delegates to action.execute/2 methods
  - **Centralized Execution**: All actions now execute through consistent ActionExecutor interface
  - **Better Separation of Concerns**: Each action type handles its own execution logic

- **Code Quality Improvements**: Enhanced code maintainability and compliance
  - **Zero Credo Issues**: All static analysis issues resolved across the codebase
  - **Unused Variable Cleanup**: Fixed unused variable warnings in Handler and ElementBuilder
  - **Alias Ordering**: Proper alphabetical alias ordering in all test files
  - **Clean Validation Pipeline**: All steps pass - format ✓ test ✓ credo ✓ dialyzer ✓

#### Test Coverage Improvements

- **13 New Passing Tests**: Unlocked additional test coverage through datamodel improvements
  - **9 SCION Tests**: Including assign actions, current small step assignments, data initialization
  - **4 W3C Tests**: Including executable content evaluation, foreach loops, conditional execution
  - **Test Categories**: `assign/`, `assign_current_small_step/`, `data/`, `foreach/`, `if_else/`
  - **Overall Progress**: Improved from 48/184 to 61/184 total tests passing (33% compliance)

- **Updated Test Baseline**: Added new passing tests to regression test suite
  - **SCION Tests**: 44 → 53 passing tests
  - **W3C Tests**: 5 → 9 passing tests
  - **Maintained Quality**: All 98 regression tests continue to pass

### Examples

#### If/Else/ElseIf Conditional Actions

```xml
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
  <state id="start">
    <onentry>
      <assign location="score" expr="85"/>
      <if cond="score >= 90">
        <assign location="grade" expr="'A'"/>
        <log label="grade" expr="'Excellent work!'"/>
      <elseif cond="score >= 80"/>
        <assign location="grade" expr="'B'"/>
        <log label="grade" expr="'Good job!'"/>
      <elseif cond="score >= 70"/>
        <assign location="grade" expr="'C'"/>
        <log label="grade" expr="'Satisfactory'"/>
      <else/>
        <assign location="grade" expr="'F'"/>
        <log label="grade" expr="'Needs improvement'"/>
      </if>
    </onentry>
  </state>
</scxml>
```

#### Nested Conditional Logic

```xml
<state id="processing">
  <onentry>
    <if cond="user.authenticated">
      <if cond="user.role == 'admin'">
        <assign location="permissions" expr="'full'"/>
        <raise event="admin_access"/>
      <else/>
        <assign location="permissions" expr="'limited'"/>
        <raise event="user_access"/>
      </if>
    <else/>
      <assign location="permissions" expr="'none'"/>
      <raise event="auth_required"/>
    </if>
  </onentry>
</state>
```

#### Mixed Actions with Conditionals

```xml
<state id="validation">
  <onentry>
    <log label="status" expr="'Starting validation'"/>
    <assign location="errors" expr="[]"/>
    <if cond="data.email == null">
      <assign location="errors[0]" expr="'Email required'"/>
    </if>
    <if cond="data.age < 18">
      <assign location="errors[1]" expr="'Must be 18 or older'"/>
    </if>
    <if cond="errors.length > 0">
      <raise event="validation_failed"/>
    <else/>
      <raise event="validation_passed"/>
    </if>
  </onentry>
</state>
```

## [1.1.0] 2025-08-26

### Added

#### Phase 1 Enhanced Expression Evaluation

- **Predicator v3.0 Integration**: Upgraded from v2.0 to v3.0 with enhanced capabilities
  - **Enhanced Nested Property Access**: Deep dot notation support (`user.profile.settings.theme`)
  - **Mixed Access Patterns**: Combined bracket/dot notation (`users['john'].active`)
  - **Context Location Resolution**: New `context_location/2` function for assignment path validation
  - **Value Evaluation**: Non-boolean expression evaluation for actual data values
  - **Type-Safe Operations**: Improved type coercion and error handling
  - **Graceful Fallback**: Returns `:undefined` for missing properties instead of errors

- **`Statifier.ValueEvaluator` Module**: Comprehensive value evaluation system for SCXML expressions
  - **Expression Compilation**: `compile_expression/1` for reusable expression compilation
  - **Value Evaluation**: `evaluate_value/2` extracts actual values (not just boolean results)
  - **Location Path Resolution**: `resolve_location/1,2` validates assignment paths using predicator v3.0
  - **Safe Assignment**: `assign_value/3` performs type-safe nested data model updates
  - **Integrated Assignment**: `evaluate_and_assign/3` combines evaluation and assignment
  - **SCXML Context Support**: Full integration with state machine context (events, configuration, datamodel)
  - **Error Handling**: Comprehensive error handling with detailed logging

- **`<assign>` Element Support**: Full W3C SCXML assign element implementation
  - **`Statifier.Actions.AssignAction` Struct**: Represents assign actions with location and expr attributes
  - **Location-Based Assignment**: Validates assignment paths before execution
  - **Expression Evaluation**: Uses Statifier.ValueEvaluator for complex expression processing
  - **Nested Property Assignment**: Supports deep assignment (`user.profile.name = "John"`)
  - **Mixed Notation Support**: Handles both dot and bracket notation in assignments
  - **Context Integration**: Access to current event data and state configuration
  - **Error Recovery**: Graceful error handling with logging, continues execution on failures
  - **Action Integration**: Seamlessly integrates with existing action execution framework

#### StateChart Data Model Enhancement

- **Datamodel Storage**: Added `datamodel` field to `Statifier.StateChart` for variable persistence
- **Current Event Context**: Added `current_event` field for expression evaluation context
- **Helper Methods**: `update_datamodel/2` and `set_current_event/2` for state management
- **SCXML Context Building**: Enhanced context building for comprehensive expression evaluation

#### Parser Extensions

- **Assign Element Parsing**: Extended SCXML parser to handle `<assign>` elements
  - **Element Builder**: `build_assign_action/4` creates AssignAction structs with location tracking
  - **Handler Integration**: Added assign element start/end handlers
  - **StateStack Integration**: `handle_assign_end/1` properly collects assign actions
  - **Mixed Action Support**: Parse assign actions alongside log/raise actions in onentry/onexit
  - **Location Tracking**: Complete source location tracking for debugging

#### Feature Detection Updates

- **Assign Elements Support**: Updated `assign_elements` feature status to `:supported`
- **Feature Registry**: Enhanced feature detection for new capabilities
- **Test Infrastructure**: Tests now recognize assign element capability

### Changed

#### Dependency Updates

- **predicator**: Upgraded from `~> 2.0` to `~> 3.0` (major version upgrade)
  - **Breaking Change**: Enhanced property access semantics
  - **Migration**: Context keys with dots now require nested structure (e.g., `%{"user" => %{"email" => "..."}}` instead of `%{"user.email" => "..."}`)
  - **Benefit**: More powerful and flexible data access patterns

### Technical Improvements

- **Test Coverage**: Maintained 92.9% overall code coverage with comprehensive new tests
  - **New Test Modules**: Statifier.ValueEvaluatorTest, Statifier.Actions.AssignActionTest, Statifier.Parser.AssignParsingTest
  - **556 Total Tests**: All tests pass including new assign functionality
  - **Log Capture**: Added `@moduletag capture_log: true` for clean test output
- **Performance**: O(1) lookups maintained with new data model operations
- **Error Handling**: Enhanced error handling and logging throughout assign operations
- **Code Quality**: Maintained Credo compliance with proper alias ordering

### Examples

#### Basic Assign Usage

```xml
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
  <state id="start">
    <onentry>
      <assign location="userName" expr="'John Doe'"/>
      <assign location="counter" expr="42"/>
      <assign location="user.profile.name" expr="'Jane Smith'"/>
    </onentry>
    <transition target="working"/>
  </state>
  <state id="working">
    <onentry>
      <assign location="counter" expr="counter + 1"/>
      <assign location="status" expr="'processing'"/>
    </onentry>
  </state>
</scxml>
```

#### Mixed Notation Assignment

```xml
<onentry>
  <assign location="users['admin'].active" expr="true"/>
  <assign location="settings.theme" expr="'dark'"/>
  <assign location="counters[0]" expr="counters[0] + 1"/>
</onentry>
```

#### Event Data Assignment

```xml
<state id="processing">
  <onentry>
    <assign location="lastEvent" expr="_event.name"/>
    <assign location="eventData" expr="_event.data.value"/>
  </onentry>
</state>
```

#### Programmatic Usage

```elixir
# Value evaluation
{:ok, compiled} = Statifier.ValueEvaluator.compile_expression("user.profile.name")
{:ok, "John Doe"} = Statifier.ValueEvaluator.evaluate_value(compiled, context)

# Location validation
{:ok, ["user", "settings", "theme"]} = Statifier.ValueEvaluator.resolve_location("user.settings.theme")

# Combined evaluation and assignment
{:ok, updated_model} = Statifier.ValueEvaluator.evaluate_and_assign("result", "count * 2", context)
```

### Notes

- **Phase 1 Complete**: Enhanced Expression Evaluation phase is fully implemented
- **Foundation for Phase 2**: Data model and expression evaluation infrastructure ready
- **Backward Compatible**: All existing functionality preserved
- **Production Ready**: Comprehensive test coverage and error handling
- **SCION Progress**: `assign_elements` feature now supported (awaiting Phase 2 for full datamodel tests)

## [1.0.0] - 2025-08-23

### Added

#### Phase 1 Executable Content Support

- **`<log>` Action Support**: Full implementation of SCXML `<log>` elements with expression evaluation
  - **`Statifier.LogAction` Struct**: Represents log actions with label and expr attributes
  - **Expression Evaluation**: Basic literal expression support (full evaluation in Phase 2)
  - **Logger Integration**: Uses Elixir Logger for output with contextual information
  - **Location Tracking**: Complete source location tracking for debugging
- **`<raise>` Action Support**: Complete implementation of SCXML `<raise>` elements for internal event generation
  - **`Statifier.RaiseAction` Struct**: Represents raise actions with event attribute
  - **Event Generation**: Logs raised events (full event queue integration in future phases)
  - **Anonymous Events**: Handles raise elements without event attributes
- **`<onentry>` and `<onexit>` Action Support**: Executable content containers for state transitions
  - **Action Collection**: Parses and stores multiple actions within onentry/onexit blocks
  - **Mixed Actions**: Support for combining log, raise, and future action types
  - **State Integration**: Actions stored in Statifier.State struct with onentry_actions/onexit_actions fields
- **Action Execution Infrastructure**: Comprehensive system for executing SCXML actions
  - **`Statifier.ActionExecutor` Module**: Centralized action execution with phase tracking
  - **Interpreter Integration**: Actions executed during state entry/exit in interpreter lifecycle
  - **Type Safety**: Pattern matching for different action types with extensibility

#### Test Infrastructure Improvements

- **Required Features System**: Automated test tagging system for feature-based test exclusion
  - **`@tag required_features:`** annotations on all W3C and SCION tests
  - **Feature Detection Integration**: Tests automatically excluded if required features unsupported
  - **262 Tests Tagged**: Comprehensive coverage of W3C and SCION test requirements
  - **Maintainable System**: Script-based tag updates for easy maintenance

#### Eventless/Automatic Transitions

- **Eventless Transitions**: Full W3C SCXML support for transitions without event attributes that fire automatically
- **Automatic Transition Processing**: Microstep loop processes chains of eventless transitions until stable configuration
- **Cycle Detection**: Prevents infinite loops with configurable iteration limits (100 iterations default)
- **Parallel Region Preservation**: Proper SCXML semantics for transitions within and across parallel regions
- **Conflict Resolution**: Child state transitions take priority over ancestor transitions per W3C specification

#### Enhanced Parallel State Support

- **Parallel State Transitions**: Fixed regression where transitions within parallel regions affected unrelated parallel regions
- **Cross-Parallel Boundaries**: Proper exit semantics when transitions cross parallel region boundaries
- **SCXML Exit State Calculation**: Implements correct W3C exit set computation for complex state hierarchies
- **Sibling State Management**: Automatic exit of parallel siblings when transitions leave their shared parent

### Fixed

- **Regression Test**: Fixed parallel state test failure (`test/scion_tests/more_parallel/test1_test.exs`)
- **SCION Test Suite**: All 4 `cond_js` tests now pass (previously 3/4)
- **Parallel Interrupt Tests**: Fixed 6 parallel interrupt test failures in regression suite
- **Code Quality**: Resolved all `mix credo --strict` issues (predicate naming, unused variables, aliases)
- **Pattern Matching Refactoring**: Converted Handler module case statements to idiomatic Elixir pattern matching
  - **`handle_event(:end_element, ...)` Function**: Refactored to separate function clauses with pattern matching
  - **`dispatch_element_start(...)` Function**: Converted from case statement to pattern matching function clauses
  - **StateStack Module**: Applied same pattern matching refactoring to action handling functions

### Changed (Breaking)

#### ActionExecutor API Modernization

- **REMOVED**: `Statifier.Actions.ActionExecutor.execute_onentry_actions/2` function clause that accepted `%Document{}` as second parameter
- **REMOVED**: `Statifier.Actions.ActionExecutor.execute_onexit_actions/2` function clause that accepted `%Document{}` as second parameter  
- **BREAKING**: These functions now only accept `%StateChart{}` as the second parameter for proper event queue integration
- **Migration**: Replace `ActionExecutor.execute_*_actions(states, document)` with `ActionExecutor.execute_*_actions(states, state_chart)`
- **Benefit**: Action execution now properly integrates with the StateChart event queue system, enabling raised events to be processed correctly

### Technical Improvements

- **SCXML Terminology Alignment**: Updated codebase to use proper SCXML specification terminology
  - **Microstep/Macrostep Processing**: Execute microsteps (single transition sets) until stable macrostep completion
  - **Exit Set Computation**: Implements W3C SCXML exit set calculation algorithm for proper state exit semantics
  - **LCCA Computation**: Full Least Common Compound Ancestor algorithm for accurate transition conflict resolution
  - **NULL Transitions**: Added SCXML specification references while maintaining "eventless transitions" terminology
- **Feature Detection**: Enhanced feature registry with newly supported capabilities
  - **Added `eventless_transitions: :supported`** to feature registry
  - **Added `log_elements: :supported`** for log action support
  - **Added `raise_elements: :supported`** for raise action support
  - **Maintained `onentry_actions: :supported`** and `onexit_actions: :supported`** status
- **Performance**: Optimized ancestor/descendant lookup using existing parent attributes
- **Test Coverage**: Comprehensive testing across all new functionality
  - **Total Tests**: 461 tests (up from 444), including extensive executable content testing
  - **New Test Files**: 13 comprehensive test files for log/raise actions and execution
  - **Coverage Improvement**: Interpreter module coverage increased from 70.4% to 83.0%
  - **Project Coverage**: Overall coverage improved from 89.0% to 92.3% (exceeds 90% minimum requirement)
- **Regression Testing**: All core functionality tests pass with no regressions

## [0.1.0] - 2025-08-20

### Added

#### Core SCXML Implementation

- **W3C SCXML Parser**: Full XML parser supporting SCXML 1.0 specification
- **State Machine Interpreter**: Synchronous, functional API for state chart execution
- **State Configuration Management**: Efficient tracking of active states with O(1) lookups
- **Event Processing**: Support for internal and external events with proper queueing
- **Document Validation**: Comprehensive validation with detailed error reporting

#### SCXML Elements Support

- **`<scxml>`**: Root element with version, initial state, and namespace support
- **`<state>`**: Compound and atomic states with nested hierarchy
- **`<initial>`**: Initial state pseudo-states for deterministic startup
- **`<transition>`**: Event-driven transitions with conditions and targets
- **`<data>`**: Data model elements for state machine variables

#### Conditional Expressions

- **`cond` Attribute**: Full support for conditional expressions on transitions
- **Predicator Integration**: Secure expression evaluation using predicator library v2.0.0
- **SCXML `In()` Function**: W3C-compliant state checking predicate
- **Logical Operations**: Support for AND, OR, NOT, and comparison operators
- **Event Data Access**: Conditions can access current event name and payload
- **Error Handling**: Invalid expressions gracefully handled per W3C specification
- **Modern Functions API**: Uses Predicator v2.0's improved custom functions approach

#### Performance Optimizations

- **Parse-time Compilation**: Conditional expressions compiled once during parsing
- **O(1) State Lookups**: Fast state and transition resolution using hash maps
- **Document Order Processing**: Deterministic transition selection
- **Memory Efficient**: Minimal memory footprint with optimized data structures

#### Developer Experience

- **Comprehensive Testing**: 426+ test cases covering all functionality
- **Integration Tests**: End-to-end testing with real SCXML documents
- **Type Safety**: Full Elixir typespec coverage for all public APIs
- **Documentation**: Detailed module and function documentation
- **Error Messages**: Clear, actionable error reporting with location information

#### Validation & Quality

- **State ID Validation**: Ensures unique and valid state identifiers
- **Transition Validation**: Validates target states exist and are reachable
- **Initial State Validation**: Enforces SCXML initial state constraints
- **Reachability Analysis**: Identifies unreachable states in state charts
- **Static Analysis**: Credo-compliant code with strict quality checks

#### Test Coverage

- **W3C Compliance**: Support for W3C SCXML test cases (excluded by default)
- **SCION Compatibility**: Integration with SCION test suite for validation
- **Unit Tests**: Comprehensive unit testing of all modules
- **Integration Tests**: Real-world SCXML document processing
- **Regression Tests**: Critical functionality protection

### Dependencies

- **saxy ~> 1.6**: Fast XML parser for SCXML document processing
- **predicator ~> 2.0**: Secure conditional expression evaluation (upgraded to v2.0 with improved custom functions API)
- **credo ~> 1.7**: Static code analysis (dev/test)
- **dialyxir ~> 1.4**: Static type checking (dev/test)
- **excoveralls ~> 0.18**: Test coverage analysis (test)

### Technical Specifications

- **Elixir**: Requires Elixir ~> 1.17
- **OTP**: Compatible with OTP 26+
- **Architecture**: Functional, immutable state machine implementation
- **Concurrency**: Thread-safe, stateless evaluation
- **Memory**: Efficient MapSet-based state tracking

### Examples

#### Basic State Machine

```xml
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="idle">
  <state id="idle">
    <transition event="start" target="working"/>
  </state>
  <state id="working">
    <transition event="finish" target="done"/>
  </state>
  <state id="done"/>
</scxml>
```

#### Conditional Transitions

```xml
<state id="validation">
  <transition event="submit" cond="score > 80" target="approved"/>
  <transition event="submit" cond="score >= 60" target="review"/>
  <transition event="submit" target="rejected"/>
</state>
```

#### SCXML In() Function

```xml
<state id="processing">
  <transition event="check" cond="In('processing') AND progress > 50" target="almost_done"/>
  <transition event="check" target="continue_working"/>
</state>
```

#### Usage

```elixir
# Parse SCXML document
{:ok, document} = Statifier.Parser.SCXML.parse(scxml_string)

# Initialize state machine
{:ok, state_chart} = Statifier.Interpreter.initialize(document)

# Send events
event = %Statifier.Event{name: "start", data: %{}}
{:ok, new_state_chart} = Statifier.Interpreter.send_event(state_chart, event)

# Check active states
active_states = new_state_chart.configuration.active_states
```

### Notes

- This is the initial release of the Statifier SCXML library
- Full W3C SCXML 1.0 specification compliance for supported features
- Production-ready with comprehensive test coverage
- Built for high-performance state machine processing in Elixir applications
- Uses Predicator v2.0 with modern custom functions API (no global function registry)

---

## About

Statifier is a W3C SCXML (State Chart XML) implementation for Elixir, providing a robust, performant state machine engine for complex application workflows.

For more information, visit: <https://github.com/riddler/sc>
