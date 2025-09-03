# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.8.0] 2025-09-02

### Added

#### Documentation Site and Infrastructure

- **VitePress Documentation Site**: Complete documentation site setup with Diataxis structure following the four documentation types (Tutorials, How-to Guides, Reference, Explanation)
- **GitHub Actions Integration**: Automatic deployment to GitHub Pages with separate workflows for documentation building and linting
- **Specialized Documentation Agent**: Added Diataxis-aware documentation agent for structured content creation and management

#### SCXML Feature Enhancements  

- **Internal Transitions**: Complete implementation of `type="internal"` transitions that execute actions without exiting/re-entering source state per W3C SCXML specification
- **Enhanced Send Elements**: Improved `<send>` element support with better content data processing, parameter validation, and JSON serialization for complex values
- **Nested If Parsing**: Fixed SAX parser to properly handle nested `<if>` blocks, enabling complex conditional logic structures

#### Performance and Developer Experience

- **Macro-Based Logging**: Converted all LogManager logging functions to performance-optimized macros with lazy evaluation and zero overhead when logging is disabled
- **Environment-Aware Logging**: Added automatic logging configuration based on environment (trace in dev, debug in test, info in prod)
- **Enhanced Debugging**: Comprehensive trace logging throughout transition resolution and action execution with structured metadata

### Fixed

- **Parallel Transition Conflicts**: Enhanced TransitionResolver to handle conflicts between transitions from parallel regions using document order per SCXML specification
- **Expression Compilation**: Moved expression compilation from creation-time to validation-time with fallback runtime compilation for backward compatibility
- **Pipeline-Friendly APIs**: Updated all action execute functions to take state_chart as first argument for better Elixir pipeline composition

### Changed

- **Feature Detection Updates**: Moved send_content_elements and send_param_elements from partial to supported status
- **Code Quality**: Resolved Credo static analysis issues by extracting helper functions and reducing cyclomatic complexity
- **Error Handling**: Improved error context logging for failed conditions and expression evaluations

### Infrastructure

- **Separated Workflows**: Split documentation workflows into focused build/deployment and linting processes
- **ESM Module Support**: Added proper ES module configuration for VitePress compatibility
- **Test Coverage**: Improved test coverage across parser components, action executors, and logging infrastructure

## [1.7.0] 2025-09-01

### Added

#### Enhanced SCXML Feature Detection and Test Infrastructure

- **Comprehensive Feature Detection**: Added detection for 8 new SCXML
  features including wildcard_events, invoke_elements, script_elements,
  cancel_elements, finalize_elements, donedata_elements,
  send_content_elements, send_param_elements, and send_delay_expressions
- **Automated Test Updates**: Created script to automatically update
  @required_features attributes across 182 test files (123 SCION + 59
  W3C) based on actual XML content analysis
- **Wildcard Events Support**: Full implementation of event="*" patterns
  with proper transition processing and comprehensive test coverage
- **Partial Feature Testing**: Modified test framework to allow :partial
  features to run, providing better feedback instead of automatic
  exclusion

#### New SCXML Elements and Features

- **Foreach Element Support**: Complete SCXML `<foreach>` implementation
  with W3C-compliant variable scoping, permanent variable declaration,
  and nested action support
- **Targetless Transitions**: Implementation of SCXML targetless
  transitions that execute actions without state changes, following W3C
  specification requirements
- **Enhanced Send Elements**: Improved `<send>` element parsing with
  proper content element text capture, fixing previously ignored text
  content in send actions

#### Development Infrastructure

- **Quality Mix Task**: Added comprehensive `mix quality` task with
  automated formatting, testing, static analysis, and coverage checking
- **Coverage Improvements**: Significantly improved test coverage across
  multiple modules including parser components, action executors, and
  logging infrastructure

### Changed

#### Test Framework Improvements

- **Enhanced Feature Validation**: Updated FeatureDetector.validate_features/1
  to treat :partial features as runnable rather than excluded
- **Improved Test Accuracy**: All test files now have precise feature
  requirements based on actual SCXML content rather than manual
  specification
- **Better Regression Coverage**: Regression test coverage improved from
  141/142 to 145/145 (100% pass rate)

#### SCXML Compliance Enhancements

- **History State Fixes**: Fixed history state restoration to properly
  execute ancestor onentry actions per W3C specification
- **Logging Improvements**: Implemented safe_to_string function to handle
  complex data types in log actions, preventing String.Chars protocol
  errors
- **Increased Iteration Limits**: Raised eventless transition iteration
  limit from 100 to 1000 to handle complex automatic transition chains

### Fixed

- **Content Element Parsing**: Fixed SAX parser to capture text content
  within `<content>` elements for send actions
- **Variable Scoping**: Proper SCXML variable scoping in foreach loops
  with restoration of existing variables after iteration
- **Feature Classification**: Corrected wildcard_events status from
  :partial to :supported with full implementation

### Benefits

- **Enhanced Test Coverage**: Comprehensive detection prevents false
  positive/negative test results with accurate feature requirements
- **Better Development Feedback**: Partial features now provide real
  feedback rather than being automatically excluded from testing
- **SCXML Compliance**: Improved adherence to W3C SCXML specification
  with proper implementation of complex features like foreach and
  targetless transitions
- **Developer Experience**: Automated quality checking and enhanced test
  infrastructure provide better development workflow

All 857+ tests continue to pass with enhanced regression coverage and
improved SCXML feature support.

## [1.6.0] 2025-08-30

### Changed

#### API Consolidation and Cleanup

- **Consolidated Active States API**: Unified active states functionality into single source of truth
  - **Renamed Functions for Clarity**: `active_states` → `active_leaf_states`, `active_ancestors` → `all_active_states`
  - **Single Source of Truth**: All active state queries now handled by `Configuration` module
  - **Removed Wrapper Functions**: Eliminated duplicate functions from `StateChart` and `Interpreter` modules
  - **Updated All Tests**: All 857 tests updated to use consolidated API directly
  - **Fixed History Tracking**: History tracking now correctly uses all active states (including ancestors) for proper shallow history computation

- **Removed Backwards Compatibility Layers**: Cleaned up legacy API functions for better maintainability
  - **Removed Legacy Delegates**: Eliminated `Statifier.validate/1` and `Statifier.interpret/1` delegate functions
  - **Removed `Statifier.parse_only/1`**: Eliminated unused function that provided no additional value over `SCXML.parse/2`
  - **Forced Explicit Module Usage**: Users must now call `Statifier.Interpreter.initialize/1` and `Statifier.Validator.validate/1` directly
  - **Updated Documentation**: All examples and README updated to use explicit module references

#### Code Quality Improvements

- **Implemented Proper Logging**: Replaced TODO comments with actual logging infrastructure
  - **Validation Warning Logging**: `Interpreter.initialize/1` now properly logs validation warnings using `LogManager`
  - **Structured Logging**: Warnings logged with warning count and detailed messages
  - **Consistent Infrastructure**: Uses existing logging system throughout codebase

- **Fixed All Credo Issues**: Resolved all static code analysis warnings
  - **Added Module Aliases**: Proper module aliasing to eliminate nested module access warnings
  - **Clean Code Standards**: All 288 source files now pass `mix credo --strict` with no issues
  - **Improved Readability**: Better import organization and alias usage

### Benefits

- **Clearer API**: Eliminates confusion between multiple similar functions
- **Better Maintainability**: Single source of truth for active state management
- **Explicit Architecture**: Direct module usage removes API ambiguity
- **Enhanced Debugging**: Proper structured logging for validation issues
- **Code Quality**: Clean codebase with no static analysis issues

All 857 tests pass with 91.2% code coverage maintained throughout the refactoring.

## [1.5.0] 2025-08-29

### Added

#### Modern API with Relaxed Parsing Mode

- **`Statifier.parse/2` Function**: New streamlined API combining parsing and validation in one call
  - **3-Tuple Return Format**: Returns `{:ok, document, warnings}` for comprehensive result handling
  - **Automatic Validation**: Validates documents by default, returns errors as `{:error, {:validation_errors, errors, warnings}}`
  - **Options Support**: Accepts keyword options for parsing customization
  - **Relaxed Mode Support**: Passes options to SCXML.parse for enhanced flexibility
  - **Skip Validation Option**: `validate: false` returns unvalidated documents for advanced use cases

- **Enhanced `SCXML.parse/2` with XML Normalization**: Comprehensive relaxed parsing mode for simplified SCXML authoring
  - **XML Declaration Handling**: Optional XML declaration addition with `xml_declaration` option (default: false to preserve line numbers)
  - **Default Namespace Addition**: Automatically adds W3C SCXML namespace when missing
  - **Default Version Addition**: Automatically adds version="1.0" when missing
  - **Backwards Compatible**: Preserves existing XML declarations and attributes when present
  - **Test-Friendly**: Eliminates XML boilerplate for cleaner test documents

- **Validation Status Tracking**: Added `validated` field to Document struct for better API clarity
  - **Document.validated**: Boolean field indicating whether document has been validated
  - **Interpreter Optimization**: Skips redundant validation for pre-validated documents
  - **Helper Function**: `Statifier.validated?/1` for checking document validation status

#### Basic Send Element Support

- **`<send>` Element Implementation**: Comprehensive Phase 1 support for SCXML send elements with internal event communication
  - **`Statifier.Actions.SendAction`**: Complete data structure with event_expr, target_expr, type_expr, delay_expr, namelist support
  - **`Statifier.Actions.SendParam`**: Support for `<param>` child elements with name/expr attributes
  - **`Statifier.Actions.SendContent`**: Support for `<content>` child elements with expr attribute
  - **Expression Evaluation**: Dynamic event names, target resolution, and data payload construction
  - **Internal Event Routing**: Events sent to #_internal properly queued and processed in state machine
  - **Transition Actions**: Send elements within `<transition>` elements with proper execution order

- **Enhanced Parser Support**: Extended SCXML parser for comprehensive send element parsing
  - **Send Element Parsing**: Complete parsing of `<send>` elements with all W3C attributes
  - **Child Element Support**: Parsing of nested `<param>` and `<content>` elements
  - **Location Tracking**: Precise source location tracking for all send-related elements
  - **Handler Integration**: SAX-based parsing with proper state stack management

- **ActionExecutor Integration**: Enhanced action execution framework with send support
  - **Transition Action Execution**: Added `execute_transition_actions/3` for actions within transitions
  - **Proper Action Order**: SCXML-compliant action execution (exit → transition → entry)
  - **Pipeline Programming**: Refactored parameter order for better |> operator usage

#### StateHierarchy Module Extraction  

- **`Statifier.StateHierarchy`**: 422-line dedicated module extracted from Interpreter for hierarchy operations
  - **8 Core Functions**: `descendant_of?/3`, `compute_lcca/3`, `get_ancestor_path/2`, `get_parallel_ancestors/2`, etc.
  - **Reduced Interpreter Size**: 824 → 636 lines (23% reduction, 188 lines extracted)
  - **Single Responsibility**: All state hierarchy logic consolidated in focused module
  - **Comprehensive Testing**: 45 new tests covering complex hierarchies, edge cases, parallel regions

#### Hierarchy Caching Infrastructure

- **`Statifier.HierarchyCache`**: O(1) performance optimization system for expensive hierarchy operations
  - **Pre-computed Relationships**: Ancestor paths, LCCA matrix, descendant sets, parallel regions
  - **Performance Gains**: 5-15x speedup for hierarchy operations (O(depth) → O(1))
  - **Memory Efficient**: ~1.5-2x memory overhead for significant performance benefits
  - **Automatic Building**: Cache built during validation phase for valid documents only
  - **Statistics Tracking**: Build time, memory usage, and cache size metrics

- **Enhanced Document Structure**: Extended Document struct with hierarchy_cache field
  - **Integration with Validation**: Cache built in Validator.finalize/2 pipeline
  - **Helper Functions**: `Document.get_all_states/1` for comprehensive state enumeration
  - **Benchmark Testing**: Performance and memory usage validation with dedicated benchmarks

#### TransitionResolver Module Extraction

- **`Statifier.Interpreter.TransitionResolver`**: 161-line focused module extracted from Interpreter
  - **Single Responsibility**: Dedicated to SCXML transition conflict resolution and matching
  - **6 Core Functions**: `find_enabled_transitions/2`, `find_eventless_transitions/1`, `resolve_transition_conflicts/2`, etc.
  - **SCXML-Compliant**: Implements W3C specification for optimal transition set computation
  - **Comprehensive Testing**: 300 lines of tests with 12 test cases covering all scenarios
  - **Better Maintainability**: Reduces Interpreter complexity from 655 to 581 lines (11% reduction)

### Changed

#### API Modernization and Backwards Compatibility

- **⚠️ BREAKING**: Updated all test files to use new 3-tuple `Statifier.parse/2` API
  - **Comprehensive Migration**: All 857 tests updated to new API format
  - **Maintained Coverage**: All tests continue passing with enhanced API
  - **Improved Test Clarity**: 3-tuple format provides better access to warnings in tests

- **Streamlined Main Module**: Complete rewrite of `/lib/statifier.ex` with modern architecture
  - **New Functions**: `parse/2` and `validated?/1` for comprehensive API coverage
  - **Error Handling**: Enhanced error handling with `handle_validation/2` helper
  - **Reduced Nesting**: Improved code maintainability with better function organization
  - **Options Integration**: Seamless integration with relaxed parsing options

#### Code Quality and Performance Improvements

- **Perfect Credo Compliance**: Achieved 0 issues across 863 analyzed modules/functions
  - **Function Nesting Depth**: Fixed all nesting depth violations in StateHierarchy module
  - **Helper Function Extraction**: Added `check_descendant_relationship/3`, `lookup_lcca_in_matrix/3`, `normalize_lcca_key/2`
  - **Clean Architecture**: Better separation of concerns and improved readability
  - **Benchmark Test Configuration**: Added Credo disable for IO.puts in benchmark tests

- **Major Interpreter Refactoring**: Comprehensive architectural improvements for better maintainability
  - **Module Extraction Benefits**: StateHierarchy, TransitionResolver, and HierarchyCache provide focused functionality
  - **Performance Optimizations**: O(1) hierarchy operations with pre-computed cache infrastructure
  - **Pipeline Programming**: Enhanced parameter ordering for better Elixir |> operator usage
  - **Action Execution Improvements**: Proper SCXML-compliant action execution order and integration
  - **Future Extensibility**: Clean architecture prepared for advanced SCXML features and optimizations

#### Enhanced Action Execution Architecture

- **ActionExecutor Parameter Refactoring**: Improved parameter ordering for better Elixir programming patterns
  - **StateChart First**: All execute_*_actions functions now put state_chart as first parameter
  - **Pipeline Friendly**: Better |> operator support for functional programming style
  - **Transition Actions**: New `execute_transition_actions/3` function for actions within transitions
  - **Separation of Concerns**: Moved transition action execution from Interpreter to ActionExecutor

### Fixed

#### XML Normalization and Location Tracking

- **Version Attribute Detection**: Fixed regex pattern in `maybe_add_default_version/1` for proper version attribute recognition
- **Location Tracking Preservation**: Ensured line number accuracy maintained with optional XML declaration
- **Function Signature Conflicts**: Resolved parse/1 vs parse/2 function definition conflicts

#### Test Infrastructure Improvements  

- **Location Tracking Tests**: Updated location-specific tests to include XML declarations for accurate line numbers
- **TransitionResolver Integration**: Fixed StateChart field name issues and event timing in extracted module tests
- **Comprehensive Test Coverage**: All 857 tests passing with new architecture and API changes

### Technical Improvements

#### Enhanced Developer Experience

- **Simplified SCXML Authoring**: Relaxed parsing mode eliminates repetitive XML boilerplate
  - **No XML Declaration Required**: Tests can omit `<?xml version="1.0" encoding="UTF-8"?>`
  - **No Namespace Required**: Automatic W3C SCXML namespace addition
  - **No Version Required**: Automatic version="1.0" addition
  - **Cleaner Test Documents**: Focus on state machine logic rather than XML syntax

- **Better Error Messages**: Enhanced validation error reporting with maintained source location accuracy
- **Improved API Consistency**: Uniform return patterns and option handling across all parsing functions
- **Comprehensive Documentation**: Updated all function documentation with examples and options

#### Performance and Quality Metrics

- **All Quality Gates Pass**: Format ✓ Test (857/857) ✓ Credo (0 issues) ✓ Dialyzer ✓
- **Comprehensive Test Coverage**: 857 total tests with significant new module coverage
  - **New Test Modules**: SendAction (236 lines), StateHierarchy (591 lines), TransitionResolver (313 lines)
  - **Advanced Testing**: Handler (483 lines), StateStack (453 lines), HierarchyCache (524 lines)
  - **Performance Benchmarks**: HierarchyCache benchmarks demonstrate 5-15x performance improvements
- **Memory Efficiency**: O(1) hierarchy operations with intelligent caching system
- **Production Ready**: All functionality thoroughly tested with comprehensive edge case coverage
- **Architecture Quality**: Clean separation of concerns with focused, testable modules

### Examples

#### New Streamlined API

```elixir
# Modern API - Parse and validate in one step
{:ok, document, warnings} = Statifier.parse(xml)

# Parse without validation for advanced use cases  
{:ok, document, []} = Statifier.parse(xml, validate: false)

# Check validation status
validated = Statifier.validated?(document)  # true/false

# Skip validation explicitly
{:ok, document, []} = Statifier.parse(xml, validate: false)
```

#### Relaxed XML Parsing Mode

```elixir
# Before v1.5.0 - Full XML boilerplate required
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
  <state id="start"/>
</scxml>
"""

# After v1.5.0 - Clean, minimal syntax
xml = """
<scxml initial="start">
  <state id="start"/>
</scxml>
"""

{:ok, document, warnings} = Statifier.parse(xml)
# XML declaration, namespace, and version automatically added
```

#### XML Declaration Control

```elixir
# Preserve line numbers (default behavior)
{:ok, document, warnings} = Statifier.parse(minimal_xml)

# Add XML declaration explicitly
{:ok, document, warnings} = Statifier.parse(minimal_xml, xml_declaration: true)
```

#### Error Handling Examples

```elixir
# Validation errors with enhanced format
case Statifier.parse(invalid_xml) do
  {:ok, document, warnings} -> 
    # Success with optional warnings
  {:error, {:validation_errors, errors, warnings}} -> 
    # Validation failed with detailed errors
  {:error, reason} -> 
    # Parsing failed
end
```

#### Send Element Usage

```xml
<scxml initial="waiting">
  <state id="waiting">
    <transition event="start" target="processing">
      <!-- Send internal event with data -->
      <send target="#_internal" event="process_data">
        <param name="userId" expr="'user123'"/>
        <param name name="priority" expr="5"/>
        <content expr="'Processing started'"/>
      </send>
    </transition>
  </state>
  
  <state id="processing">
    <transition event="process_data" target="complete">
      <!-- Event data available via _event.data -->
      <log expr="'Processing for user: ' + _event.data.userId"/>
    </transition>
  </state>
  
  <state id="complete"/>
</scxml>
```

#### Dynamic Send Elements

```xml
<state id="router">
  <transition event="route_message">
    <!-- Dynamic event and target evaluation -->
    <send targetexpr="_event.data.target" 
          eventexpr="_event.data.eventName"
          namelist="status priority">
      <param name="timestamp" expr="Date.now()"/>
    </send>
  </transition>
</state>
```

#### Performance Optimization Examples

```elixir
# Before v1.5.0 - O(depth) hierarchy operations
time_uncached = benchmark_hierarchy_operations(uncached_document)

# After v1.5.0 - O(1) hierarchy operations with caching
{:ok, cached_document, _warnings} = Statifier.parse(xml)
time_cached = benchmark_hierarchy_operations(cached_document)

# Typical performance improvement: 5-15x speedup
speedup = time_uncached / time_cached  # => ~10.5x
```

### Migration Guide

#### API Updates

```elixir
# Before v1.5.0
{:ok, document} = SCXML.parse(xml)
{:ok, validated_doc, warnings} = Validator.validate(document)

# After v1.5.0 - Streamlined approach
{:ok, document, warnings} = Statifier.parse(xml)
```

#### Test Simplification

```elixir
# Before v1.5.0 - Verbose XML
xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="idle">
  <state id="idle">
    <transition event="start" target="running"/>
  </state>
  <state id="running"/>
</scxml>
"""

# After v1.5.0 - Focus on logic
xml = """
<scxml initial="idle">
  <state id="idle">
    <transition event="start" target="running"/>
  </state>
  <state id="running"/>
</scxml>
"""
```

### Notes

- **Major Release**: Comprehensive modernization spanning API, architecture, performance, and new SCXML features
- **API Modernization**: Complete modernization of parsing and validation API for better developer experience
- **Architectural Revolution**: Major refactoring with StateHierarchy, TransitionResolver, HierarchyCache, and SendAction modules
- **Performance Breakthrough**: O(1) hierarchy operations provide 5-15x performance improvements for complex state machines
- **SCXML Feature Expansion**: Basic send element support enables internal event communication and transition actions
- **Quality Excellence**: Perfect Credo compliance, comprehensive test coverage (857 tests), and thorough documentation
- **Developer Productivity**: Significant reduction in XML boilerplate and improved error handling
- **Production Ready**: Battle-tested architecture with comprehensive edge case coverage and benchmark validation
- **Foundation for Future**: Clean, extensible architecture prepares for advanced SCXML features (delays, external targets, etc.)

## [1.4.0] 2025-08-29

### Added

#### Complete SCXML History State Support

- **History State Data Model**: Full support for SCXML `<history>` elements per W3C specification
  - **`Statifier.State` Extensions**: Added `history_type` field (`:shallow | :deep`) and `history_type_location` for validation
  - **Parser Support**: Complete parsing of `<history>` elements with `type="shallow|deep"` attributes
  - **Default Behavior**: History type defaults to `:shallow` when not specified
  - **Element Builder**: New `build_history_state/4` function for creating history state structures
  - **Location Tracking**: Full source location tracking for history elements and attributes

- **History State Validation**: Comprehensive validation per W3C SCXML specification requirements
  - **`Statifier.Validator.HistoryStateValidator`**: Dedicated validator module for all history constraints
  - **Structural Validation**: History states cannot be at root level (must have compound/parallel parent)
  - **Content Validation**: History states cannot have child states (pseudo-states only)
  - **Uniqueness Validation**: Only one history state per type (shallow/deep) per parent state
  - **Type Validation**: History type must be valid (`:shallow` or `:deep`)
  - **Target Validation**: Default transition targets must exist in document
  - **Reachability Analysis**: Warns if history states are unreachable (no transitions target them)

- **History Tracking Infrastructure**: Complete W3C SCXML compliant history recording and restoration
  - **`Statifier.HistoryTracker`**: Core history state tracking with efficient MapSet operations
  - **Shallow History**: Records and restores immediate children of parent state that contain active descendants
  - **Deep History**: Records and restores all atomic descendant states within parent state
  - **StateChart Integration**: History tracking integrated into StateChart lifecycle
  - **Record History API**: `record_history/2`, `get_shallow_history/2`, `get_deep_history/2`, `has_history?/2`

- **History State Resolution**: Full W3C SCXML compliant history state transition resolution
  - **Pseudo-State Handling**: History states resolve to stored configuration or default targets (never active themselves)
  - **Shallow Resolution**: Restores immediate children from recorded shallow history
  - **Deep Resolution**: Restores all atomic descendants from recorded deep history  
  - **Default Transitions**: Uses history state's default transitions when parent has no recorded history
  - **Complex Hierarchy Support**: Maintains proper state hierarchy during restoration

#### Multiple Transition Target Support

- **Space-Separated Target Parsing**: SCXML transitions now support multiple targets per W3C specification
  - **Parser Enhancement**: Handles `target="state1 state2 state3"` syntax with proper whitespace splitting
  - **Data Model**: `Statifier.Transition.targets` field (list) replaces `target` field (string)  
  - **Validator Updates**: All transition validators updated for list-based target validation
  - **Empty Target Support**: Empty target lists properly handled for targetless transitions
  - **Feature Detection**: Updated feature detection to recognize multiple target capability

- **Enhanced Parallel State Exit Logic**: Critical fix for W3C SCXML parallel state exit semantics
  - **Exit Set Computation**: Proper W3C SCXML exit set calculation for complex parallel hierarchies
  - **Parallel Ancestor Detection**: `get_parallel_ancestors/3` identifies all parallel ancestors in hierarchy
  - **Region Identification**: `are_in_parallel_regions/3` correctly identifies states in different parallel regions
  - **Cross-Boundary Exits**: `exits_parallel_region/3` detects transitions that exit parallel regions
  - **Comprehensive Exit Logic**: All parallel regions properly exited when transitioning to external states

### Changed

#### API Improvements (Breaking Changes)

- **⚠️ BREAKING**: `Statifier.Transition` struct field renamed from `target` to `targets`
  - **Type Change**: `target: String.t() | nil` → `targets: [String.t()]`
  - **Migration**: Update pattern matches from `%Transition{target: target}` to `%Transition{targets: targets}`
  - **Benefit**: Self-documenting code that clearly indicates list-based target support
  - **Validation**: All existing tests and validators updated for new API

#### Document Helper Functions

- **`Statifier.Document` Enhancements**: New helper functions for history state runtime management
  - **`is_history_state?/2`**: Check if state has history type with O(1) lookup
  - **`find_history_states/2`**: Find all history states within a parent state
  - **`get_history_default_targets/2`**: Get default transition targets for history state
  - **Optimized Performance**: All functions use existing O(1) state_lookup maps

#### History Integration in Interpreter

- **Interpreter History Support**: Complete integration of history states into state machine lifecycle
  - **History Recording**: Automatic history recording before onexit actions during state transitions
  - **W3C Timing Compliance**: History recorded "before taking any transition that exits the parent"
  - **Parent Detection**: `find_parents_with_history/2` identifies parents needing history recording
  - **Ancestor Analysis**: `get_ancestors_with_history/2` finds all ancestors with history children
  - **StateChart Parameters**: Enhanced interpreter functions to work with StateChart for history access

### Fixed

#### SCION Test Coverage Improvements

- **History Test Parsing**: Fixed critical parser bug where transitions inside `<history>` elements weren't being processed
  - **StateStack Fix**: Added missing `{"history", parent_state}` case in `handle_transition_end/1`
  - **History Default Transitions**: History states can now have proper default transitions
  - **SCION History Tests**: 5/8 SCION history tests now passing (62.5% success rate, up from 12.5%)
  - **Test Results**: history0, history1, history2, history3, history6 now pass

- **Parallel State Exit Logic**: Resolved critical parallel state exit semantics issues
  - **Cross-Region Transitions**: Fixed transitions from parallel regions to external states
  - **Exit Set Calculation**: Proper W3C SCXML exit set computation for complex hierarchies
  - **SCION Test Fixes**: Multiple SCION history tests (history4b, history5) now pass completely
  - **Regression Protection**: All 118 regression tests continue to pass

#### Feature Detection Updates

- **History State Support**: Updated `FeatureDetector` to mark `:history_states` as `:supported`
- **Multiple Target Support**: Enhanced feature detection for multiple transition targets
- **Test Infrastructure**: 12 history state tests (8 SCION + 4 W3C) now properly validated

### Technical Improvements

#### Test Infrastructure

- **Comprehensive Test Coverage**: 707 total tests with enhanced history state coverage
  - **New Test Organization**: Created `test/statifier/history/` folder for organized history testing
  - **History Test Suite**: 15+ dedicated history tests covering all scenarios (recording, restoration, validation)
  - **Integration Tests**: End-to-end testing of history states with complex state hierarchies
  - **Regression Tests**: All 118 regression tests continue passing with new functionality

#### Code Quality

- **Credo Compliance**: All static analysis issues resolved across the codebase
- **Pattern Matching**: Enhanced pattern matching for cleaner, more readable code
- **Type Safety**: Full typespec coverage for all new history state functionality  
- **Documentation**: Comprehensive documentation for all new modules and functions
- **Performance**: Maintained O(1) lookups with efficient MapSet operations for history tracking

#### W3C SCXML Compliance

- **History State Specification**: Full compliance with W3C SCXML 1.0 history state requirements
- **Parallel State Semantics**: Proper W3C exit set computation and parallel region handling
- **Multiple Target Support**: Compliant with W3C SCXML multiple target syntax
- **Pseudo-State Handling**: Correct implementation of history as non-active pseudo-states
- **Default Transition Logic**: Proper handling of history default transitions per specification

### Examples

#### History State Usage

```xml
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
  <state id="main" initial="sub1">
    <!-- Shallow history - restores immediate children -->
    <history id="main_hist" type="shallow">
      <transition target="sub1"/>  <!-- Default when no history -->
    </history>
    
    <state id="sub1">
      <transition event="go" target="sub2"/>
    </state>
    
    <state id="sub2">
      <transition event="go" target="sub3"/>
    </state>
    
    <state id="sub3">
      <transition event="exit" target="other"/>
      <transition event="back" target="main_hist"/>  <!-- Restore history -->
    </state>
  </state>
  
  <state id="other">
    <transition event="return" target="main_hist"/>  <!-- Restore to last sub-state -->
  </state>
</scxml>
```

#### Deep History Example

```xml
<parallel id="game">
  <!-- Deep history - restores all atomic descendants -->
  <history id="game_hist" type="deep">
    <transition target="level1"/>  <!-- Default: start at level 1 -->
  </history>
  
  <state id="progress" initial="level1">
    <state id="level1">
      <state id="checkpoint1"/>
      <state id="checkpoint2"/>
    </state>
    <state id="level2">
      <state id="checkpoint3"/>
      <state id="checkpoint4"/>
    </state>
  </state>
  
  <state id="inventory" initial="empty">
    <state id="empty"/>
    <state id="sword"/>
    <state id="shield"/>
  </state>
</parallel>
```

#### Multiple Target Transitions

```xml
<state id="source">
  <!-- Multiple targets - enter multiple states simultaneously -->
  <transition event="activate" target="target1 target2 target3"/>
</state>

<parallel id="system">
  <state id="target1"/>
  <state id="target2"/>  
  <state id="target3"/>
</parallel>
```

#### Programmatic History Usage

```elixir
# Check if state is a history state
Document.is_history_state?(document, "main_hist")  # true

# Find all history states in a parent
history_states = Document.find_history_states(document, "main")

# Get default targets for history state
defaults = Document.get_history_default_targets(document, "main_hist")

# Record and retrieve history
state_chart = StateChart.record_history(state_chart, "main")
shallow_history = StateChart.get_shallow_history(state_chart, "main")
deep_history = StateChart.get_deep_history(state_chart, "main")
```

### Migration Guide

#### Transition Target API

```elixir
# Before v1.4.0
%Transition{target: "state1"}
%Transition{target: nil}  # targetless

# After v1.4.0  
%Transition{targets: ["state1"]}
%Transition{targets: []}  # targetless

# Pattern matching migration
case transition do
  %Transition{target: nil} -> # targetless
  %Transition{target: target} -> # has target
end

# becomes
case transition do
  %Transition{targets: []} -> # targetless
  %Transition{targets: targets} -> # has targets
end
```

### Notes

- **History State Foundation**: Complete foundation for SCXML history states established
- **W3C Compliance**: Full compliance with W3C SCXML 1.0 history state specification  
- **Multiple Target Support**: Enhanced SCXML transition capability per specification
- **Parallel State Fixes**: Critical parallel state exit logic issues resolved
- **Test Coverage**: Comprehensive test coverage maintained (91.8% overall)
- **Production Ready**: All functionality thoroughly tested and validated
- **SCION Progress**: Significant improvement in SCION history test compliance

## [1.3.0] 2025-08-27

### Added

#### Core Logging Infrastructure

- **Flexible Protocol-Based Logging System**: Complete logging architecture for state chart operations
  - **`Statifier.Logging.Adapter` Protocol**: Extensible logging backend interface with `log/5` and `enabled?/2` functions
  - **`Statifier.Logging.ElixirLoggerAdapter`**: Production logging adapter that integrates with Elixir's Logger system
  - **`Statifier.Logging.TestAdapter`**: In-memory log storage adapter for clean test environments
  - **`Statifier.Logging.LogManager`**: Central coordination module with automatic metadata extraction
  - **Log Level Hierarchy**: Complete support for `:trace`, `:debug`, `:info`, `:warn`, `:error` levels with filtering

- **Automatic Metadata Extraction**: StateChart context automatically added to all log messages
  - **Current State Tracking**: Active states automatically included in log metadata
  - **Event Context**: Current event name automatically included when available
  - **Custom Metadata Support**: Additional metadata can be provided per log message
  - **Metadata Precedence**: Custom metadata takes precedence over automatic extraction

- **Advanced Memory Management**: Circular buffer support for bounded log storage
  - **Configurable Limits**: TestAdapter supports optional `max_entries` for memory-bounded logging
  - **Circular Buffer Behavior**: Automatically removes oldest entries when limit exceeded
  - **Unlimited Storage**: Optional unlimited log storage for comprehensive test coverage
  - **Helper Functions**: `get_logs/1,2`, `clear_logs/1` for test log inspection and management

- **StateChart Integration**: Enhanced StateChart structure with logging capabilities
  - **Logging Fields**: Added `log_adapter`, `log_level`, and `logs` fields to StateChart struct
  - **Configuration Helpers**: `configure_logging/3` and `set_log_level/2` functions for easy setup
  - **Seamless Integration**: Logging works with existing StateChart lifecycle and event processing

#### Logging Configuration System

- **Enhanced `Interpreter.initialize/2`**: Comprehensive logging configuration support during state chart initialization
  - **Runtime Configuration Options**: Accept `:log_adapter` and `:log_level` options via keyword list
  - **Adapter Configuration Flexibility**: Support for direct adapter structs or `{Module, opts}` tuples
  - **Backward Compatibility**: Existing `initialize/1` calls continue to work with sensible defaults
  - **Comprehensive Documentation**: Detailed examples and usage patterns in function documentation

- **Centralized Configuration Logic**: All configuration logic consolidated in `LogManager.configure_from_options/2`
  - **Configuration Precedence**: Runtime options > Application config > Environment defaults
  - **Application Configuration Support**: Integration with `Application.get_env/3` for system-wide settings
  - **Robust Error Handling**: Graceful fallback to ElixirLoggerAdapter on invalid configurations
  - **Validation and Safety**: Comprehensive configuration validation with detailed error messages

- **Production-Ready Defaults**: Sensible defaults that work across all environments
  - **ElixirLoggerAdapter Default**: Always the base default for robust logging in all environments
  - **Test Environment Configuration**: TestAdapter configured via `test_helper.exs` for clean test output
  - **Flexible Fallback Strategy**: Invalid configurations always fall back to most robust adapter
  - **Environment Independence**: No dependency on `Mix.env()` or custom environment detection

- **Comprehensive Configuration Testing**: 12 dedicated tests covering all configuration scenarios
  - **Runtime Configuration Tests**: Verification of all option types and combinations
  - **Application Configuration Tests**: Testing precedence and override behavior
  - **Error Handling Tests**: Validation of graceful fallback for invalid configurations
  - **Integration Tests**: End-to-end testing of configuration system with state chart initialization

### Examples

#### Core Logging Infrastructure

```elixir
# Configure logging with TestAdapter for testing
adapter = %Statifier.Logging.TestAdapter{max_entries: 100}
state_chart = StateChart.configure_logging(state_chart, adapter, :debug)

# Configure logging with ElixirLoggerAdapter for production
adapter = %Statifier.Logging.ElixirLoggerAdapter{}
state_chart = StateChart.configure_logging(state_chart, adapter, :info)

# Log messages with automatic metadata extraction
state_chart = LogManager.info(state_chart, "Processing started", %{action_type: "initialization"})
state_chart = LogManager.error(state_chart, "Validation failed", %{field: "email"})

# Inspect captured logs in tests
logs = TestAdapter.get_logs(state_chart)
error_logs = TestAdapter.get_logs(state_chart, :error)
state_chart = TestAdapter.clear_logs(state_chart)
```

#### Production Logging Integration

```elixir
# Initialize state chart with production logging
{:ok, state_chart} = Interpreter.initialize(document)
adapter = %Statifier.Logging.ElixirLoggerAdapter{}
state_chart = StateChart.configure_logging(state_chart, adapter, :info)

# All state chart operations now include automatic logging
{:ok, state_chart} = Interpreter.send_event(state_chart, event)
# Logs: [info] Processing event "start" current_state=["idle"] event="start"
```

#### Test Environment Usage

```elixir
defmodule MyStateMachineTest do
  use ExUnit.Case

  test "validates error logging during processing" do
    adapter = %Statifier.Logging.TestAdapter{max_entries: 50}
    state_chart = StateChart.configure_logging(state_chart, adapter, :debug)
    
    # ... perform operations that should log ...
    
    # Verify specific log messages were captured
    logs = TestAdapter.get_logs(state_chart)
    assert [%{level: :error, message: "Validation failed"}] = logs
    
    # Check metadata extraction
    assert logs |> hd() |> Map.get(:metadata) |> Map.get(:current_state) == ["processing"]
  end
end
```

#### Logging Configuration System

```elixir
# Use default configuration (ElixirLoggerAdapter, :info level)
{:ok, state_chart} = Interpreter.initialize(document)

# Configure with runtime options
{:ok, state_chart} = Interpreter.initialize(document, [
  log_adapter: {TestAdapter, [max_entries: 50]},
  log_level: :debug
])

# Configure with direct adapter struct
adapter = %TestAdapter{max_entries: 100}
{:ok, state_chart} = Interpreter.initialize(document, 
  log_adapter: adapter,
  log_level: :trace
)

# Configure via application environment (in config files or test_helper.exs)
Application.put_env(:statifier, :default_log_adapter, {TestAdapter, [max_entries: 200]})
Application.put_env(:statifier, :default_log_level, :warn)
{:ok, state_chart} = Interpreter.initialize(document)  # Uses application config
```

#### Configuration Precedence Examples

```elixir
# Application configuration
Application.put_env(:statifier, :default_log_adapter, {TestAdapter, [max_entries: 300]})
Application.put_env(:statifier, :default_log_level, :error)

# Runtime options override application config
{:ok, state_chart} = Interpreter.initialize(document, [
  log_adapter: {ElixirLoggerAdapter, []},  # Overrides TestAdapter
  log_level: :info                         # Overrides :error
])

# Invalid configurations fall back gracefully
{:ok, state_chart} = Interpreter.initialize(document, [
  log_adapter: {NonExistentModule, []}     # Falls back to ElixirLoggerAdapter
])
```

### Changed

#### Logger to LogManager Migration

- **Centralized Logging Architecture**: Migrated all existing `Logger.*` calls throughout the codebase to use the new `LogManager.*` API
  - **ActionExecutor**: All debug logging now uses `LogManager.debug` with structured metadata (action_type, state_id, phase, etc.)
  - **LogAction**: Replaced `Logger.info` with `LogManager.info`, now returns updated StateChart from logging operations
  - **RaiseAction**: Migrated `Logger.info` to `LogManager.info` with event metadata, properly threads StateChart through logging calls
  - **AssignAction**: Updated `Logger.error` to `LogManager.error` with comprehensive error context and assignment details  
  - **Datamodel**: Replaced `Logger.debug` calls with `LogManager.debug` for expression evaluation failures

- **Structured Logging Enhancement**: All LogManager calls now include appropriate context-specific metadata
  - **Action Context**: Debug logs include action_type, state_id, and execution phase information
  - **Error Context**: Error logs include detailed failure information, locations, and expressions
  - **Event Context**: Event-related logs include event names and metadata
  - **Expression Context**: Expression evaluation logs include compiled expressions and error details

- **StateChart Threading**: Actions now properly return updated StateChart instances from logging operations
  - **Consistent Return Values**: All action modules maintain StateChart consistency through logging calls
  - **State Preservation**: Logging operations preserve and return the complete StateChart state
  - **Queue Management**: Internal and external event queues remain intact through logging operations

#### Log Storage Optimization

- **Chronological Log Ordering**: TestAdapter now stores logs in intuitive chronological order (oldest first, newest last)
  - **Natural Reading Order**: Logs now appear in the order they were created for easier debugging
  - **Standard Behavior**: Aligns with typical logging system expectations and developer intuitions
  - **Improved Test Assertions**: `assert_log_order` now uses ascending index order for cleaner test logic

- **Memory Management**: Updated circular buffer behavior to maintain chronological ordering
  - **FIFO Behavior**: When max_entries limit is reached, oldest entries are removed first
  - **Append Operations**: New log entries are appended to maintain chronological sequence
  - **Backward Compatibility**: API remains unchanged while improving internal behavior

#### Test Infrastructure Enhancements  

- **StateChart Log Integration**: All action tests now use StateChart logs instead of `capture_log` for verification
  - **Helper Functions**: Added `test_state_chart()` helper for properly configured StateChart instances
  - **Log Assertions**: Created `assert_log_entry()` and `assert_log_order()` helpers for clean log verification
  - **Configuration Helpers**: Added `create_configured_state_chart()` helpers to reduce test duplication

- **Test Coverage Maintenance**: Maintained 91.2% test coverage with comprehensive log assertion coverage
  - **Regression Protection**: All 108 regression tests continue passing with new logging infrastructure
  - **Action Coverage**: Complete test coverage for all action logging behaviors
  - **Error Handling**: Comprehensive test coverage for logging error scenarios

## [1.2.0] 2025-08-27

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
