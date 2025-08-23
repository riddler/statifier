# SCXML Implementation Plan

## Executive Summary

This document outlines the comprehensive plan to achieve near-complete SCXML (State Chart XML) compliance by implementing missing executable content and data model features. The plan is based on systematic analysis of 444 tests across SCION and W3C test suites.

**Current Status**: 294/444 tests passing (66.2% coverage)  
**Target Goal**: 440+/444 tests passing (98%+ coverage)  
**Timeline**: 8-12 weeks across three implementation phases  

## Current Test Coverage Analysis

### Test Suite Breakdown

- **SCION Tests**: 127 test files from the SCION JavaScript SCXML implementation
- **W3C SCXML Tests**: 59 test files from official W3C SCXML conformance suite
- **Internal Tests**: 444 comprehensive unit and integration tests
- **Regression Suite**: 63 critical tests that must always pass

### Current Status (444 Total Tests)

- ✅ **294 tests passing (66.2%)** - Strong foundation with basic state machines working
- ❌ **150 tests failing (33.8%)** - Blocked by missing executable content and data model features
- 🔄 **34 tests in regression suite** - All basic state machine functionality validated

### Working Features (Supporting 294 Passing Tests)

- ✅ Basic state transitions and event processing
- ✅ Compound states with hierarchical entry/exit
- ✅ Parallel states with concurrent execution
- ✅ Initial state elements and configuration
- ✅ Eventless/automatic transitions (NULL transitions)
- ✅ Conditional transitions with `cond` attribute support
- ✅ SCXML-compliant processing (microstep/macrostep, exit sets, LCCA)
- ✅ Transition conflict resolution

## Missing Features Analysis

### Feature Impact Assessment (Tests Blocked)

| Feature Category | Tests Affected | Impact Level | Implementation Complexity |
|-----------------|---------------|--------------|-------------------------|
| **onentry_actions** | 78 tests | 🔴 Critical | Medium |
| **log_elements** | 72 tests | 🔴 Critical | Low |
| **datamodel** | 64 tests | 🔴 Critical | High |
| **data_elements** | 64 tests | 🔴 Critical | High |
| **assign_elements** | 48 tests | 🟡 High | Medium |
| **raise_elements** | 48 tests | 🟡 High | Medium |
| **send_elements** | 34 tests | 🟡 Medium | Medium |
| **onexit_actions** | 21 tests | 🟡 Medium | Medium |
| **history_states** | 12 tests | 🟢 Low | Medium |
| **script_elements** | 8 tests | 🟢 Low | High |

### Core Problem Identification

1. **Parser Limitations**: Current parser only handles structural SCXML elements (states, transitions, parallel) but treats executable content as "unknown" and skips it
2. **Missing Action Execution**: The interpreter has no mechanism to execute actions during state transitions (onentry, onexit, transition actions)  
3. **No Data Model**: No variable storage, expression evaluation, or data manipulation capabilities
4. **No Internal Events**: Cannot generate or process internal events via `<raise>` elements
5. **Limited Expression Engine**: Only basic condition evaluation, no full JavaScript expressions

## Three-Phase Implementation Strategy

### Phase 1: Basic Executable Content (2-3 weeks)

**Objective**: Unlock 80-100 additional tests (30% improvement)  
**Target Coverage**: From 66% to ~85%

#### Features to Implement

- **`<onentry>` Actions**: Execute actions when entering states
- **`<onexit>` Actions**: Execute actions when exiting states  
- **`<raise event="name"/>` Elements**: Generate internal events for immediate processing
- **`<log expr="message"/>` Elements**: Debug logging with expression evaluation
- **Action Execution Framework**: Infrastructure for processing nested executable content

#### Technical Architecture

```elixir
# Parser Extensions
defmodule SC.Parser.SCXML.ExecutableContent do
  def parse_onentry(attrs, children) -> %SC.OnEntryAction{}
  def parse_onexit(attrs, children) -> %SC.OnExitAction{}
  def parse_raise(attrs) -> %SC.RaiseEvent{}
  def parse_log(attrs) -> %SC.LogAction{}
end

# Data Structures  
defmodule SC.OnEntryAction do
  defstruct [:actions, :source_location]
end

defmodule SC.RaiseEvent do
  defstruct [:event, :source_location]
end

# Interpreter Integration
defmodule SC.Interpreter.ActionExecutor do
  def execute_onentry_actions(state, context) do
    # Execute all onentry actions for state
  end
  
  def process_raised_events(state_chart, events) do
    # Process internal events in current macrostep
  end
end
```

#### Expected Outcomes

- **~374 tests passing (~84%)** - Up from 294 tests
- **~70 tests failing** - Down from 150 tests  
- **SCION Compatibility**: ~90% of basic SCXML functionality
- **Regression Suite**: Expand to ~100+ validated tests

### Phase 2: Data Model & Expression Evaluation (4-6 weeks)

**Objective**: Unlock 50-70 additional tests (25% improvement)  
**Target Coverage**: From ~85% to ~95%

#### Features to Implement

- **`<datamodel>` Structure**: Root container for state machine variables
- **`<data id="var" expr="value"/>` Elements**: Variable declaration and initialization
- **`<assign location="var" expr="value"/>` Actions**: Dynamic variable assignment
- **Enhanced Expression Engine**: Full JavaScript expression evaluation with datamodel access
- **Variable Scoping**: Proper variable lifecycle and scoping per SCXML specification

#### Technical Architecture

```elixir
# Data Model Support
defmodule SC.DataModel do
  defstruct [:variables, :scoped_contexts]
  
  def get_variable(datamodel, name) -> value
  def set_variable(datamodel, name, value) -> updated_datamodel  
  def evaluate_expression(expr, datamodel) -> result
end

# Enhanced Condition Evaluator
defmodule SC.ConditionEvaluator do
  def evaluate_with_datamodel(compiled_cond, context, datamodel) do
    # Evaluate conditions with access to datamodel variables
  end
end

# JavaScript Integration
defmodule SC.JSEngine do  
  def evaluate_expression(expr_string, variables) -> {:ok, result} | {:error, reason}
  def compile_expression(expr_string) -> {:ok, compiled} | {:error, reason}
end
```

#### Expected Outcomes

- **~420 tests passing (~95%)** - Near-complete SCXML support
- **~24 tests failing** - Only advanced features missing
- **W3C Compliance**: High conformance to SCXML specification  
- **Production Ready**: Full datamodel and expression capabilities

### Phase 3: Advanced Features (2-3 weeks)  

**Objective**: Achieve comprehensive SCXML support (98%+ coverage)  
**Target Coverage**: From ~95% to ~98%+

#### Features to Implement

- **`<history type="shallow|deep"/>` States**: State history preservation and restoration
- **`<send event="name" target="target" delay="5s"/>` Elements**: External event sending with scheduling
- **`<script>` Elements**: Inline JavaScript execution within states
- **Internal Transitions**: `type="internal"` transition behavior (no state exit/entry)
- **Targetless Transitions**: Transitions without target attribute for pure action execution

#### Technical Architecture

```elixir
# History State Support
defmodule SC.HistoryTracker do
  def save_history(state_id, configuration, type) -> updated_tracker
  def restore_history(history_state, tracker) -> target_states
end

# Event Scheduling  
defmodule SC.EventScheduler do
  def schedule_event(event, delay, target) -> event_id
  def process_scheduled_events(current_time) -> [events]
end

# Script Execution
defmodule SC.ScriptExecutor do
  def execute_script(script_content, datamodel) -> updated_datamodel
end
```

#### Expected Outcomes

- **~440+ tests passing (~98%+)** - Comprehensive SCXML implementation
- **<4 tests failing** - Only edge cases or specification ambiguities
- **Industry Leading**: One of the most complete SCXML implementations available
- **Full W3C Compliance**: Meets or exceeds official SCXML specification requirements

## Implementation Details

### Parser Architecture Changes

#### Current Parser Limitations

- Only handles structural elements: `<scxml>`, `<state>`, `<parallel>`, `<transition>`, `<initial>`, `<data>`
- Treats executable content as "unknown" and skips parsing
- No support for nested action sequences

#### Proposed Parser Enhancements

```elixir
# New executable content parsing
def handle_start_element("onentry", attrs, state) do
  start_executable_content_context(:onentry, attrs, state)
end

def handle_start_element("raise", attrs, %{executable_context: context} = state) do
  add_action_to_context(context, parse_raise_action(attrs), state)
end

def handle_start_element("assign", attrs, %{executable_context: context} = state) do
  add_action_to_context(context, parse_assign_action(attrs), state)  
end
```

### Interpreter Architecture Changes

#### Current Interpreter Flow

1. Initialize configuration → Enter initial states
2. Process event → Find enabled transitions  
3. Execute transitions → Update configuration
4. Execute microsteps → Return stable configuration

#### Enhanced Interpreter Flow

1. Initialize configuration → **Execute datamodel initialization** → Enter initial states → **Execute onentry actions**
2. Process event → Find enabled transitions
3. **Execute onexit actions** → Execute transitions → **Execute transition actions** → Update configuration → **Execute onentry actions**
4. **Process raised events** → Execute microsteps → Return stable configuration

### Feature Detection Integration

Update `SC.FeatureDetector.feature_registry/0` to reflect new capabilities:

```elixir
def feature_registry do
  %{
    # Phase 1 Features
    onentry_actions: :supported,
    onexit_actions: :supported, 
    raise_elements: :supported,
    log_elements: :supported,
    
    # Phase 2 Features  
    datamodel: :supported,
    data_elements: :supported,
    assign_elements: :supported,
    script_elements: :supported,
    
    # Phase 3 Features
    history_states: :supported,
    send_elements: :supported,
    internal_transitions: :supported,
    targetless_transitions: :supported,
    
    # Still unsupported
    invoke_elements: :unsupported,
    finalize_elements: :unsupported
  }
end
```

## Risk Assessment and Mitigation

### Implementation Risks

| Risk Category | Risk Level | Mitigation Strategy |
|---------------|------------|-------------------|
| **JavaScript Integration Complexity** | 🔴 High | Use proven Elixir-JS bridge libraries (NodeJS/V8) |
| **Performance Impact** | 🟡 Medium | Implement caching, lazy evaluation, benchmarking |
| **Regression Introduction** | 🟡 Medium | Expand regression suite, feature flags, incremental rollout |
| **Specification Ambiguity** | 🟡 Medium | Reference SCION implementation, W3C test expectations |
| **Development Timeline** | 🟢 Low | Phased approach allows for scope adjustment |

### Quality Assurance Strategy

1. **Incremental Development**: Each phase delivers working, testable functionality
2. **Regression Protection**: Expand regression suite from 63 to 200+ tests after each phase
3. **Feature Flags**: Allow optional enabling of new features for stability
4. **Comprehensive Testing**: Validate against both SCION and W3C suites continuously  
5. **Performance Benchmarking**: Monitor execution speed and memory usage
6. **Documentation Updates**: Keep all documentation current with new capabilities

## Expected Business Impact

### Technical Benefits

- **Near-Complete SCXML Compliance**: Industry-leading implementation quality
- **Production Readiness**: Full executable content and datamodel support
- **Developer Experience**: Comprehensive state machine capabilities
- **Test Coverage**: 98%+ validation across comprehensive test suites

### Strategic Benefits  

- **Market Differentiation**: Most complete SCXML library in Elixir ecosystem
- **Enterprise Adoption**: Full W3C compliance enables enterprise use cases
- **Community Growth**: Comprehensive feature set attracts broader developer adoption
- **Ecosystem Leadership**: Reference implementation for SCXML in functional programming

## Success Metrics

### Phase 1 Success Criteria (Week 3)

- [ ] 370+ tests passing (83%+ coverage)
- [ ] All onentry/onexit actions executing correctly
- [ ] Internal event generation and processing working
- [ ] Logging infrastructure operational
- [ ] No regression in existing 294 passing tests

### Phase 2 Success Criteria (Week 9)

- [ ] 415+ tests passing (93%+ coverage)  
- [ ] Full datamodel variable storage and retrieval
- [ ] JavaScript expression evaluation integrated
- [ ] Variable assignment during transitions working
- [ ] Complex SCION datamodel tests passing

### Phase 3 Success Criteria (Week 12)

- [ ] 435+ tests passing (98%+ coverage)
- [ ] History state preservation and restoration working
- [ ] Event scheduling and delayed sending operational
- [ ] All major SCXML features implemented
- [ ] W3C compliance test suite passing

### Final Success Criteria

- [ ] **98%+ test coverage** across combined SCION + W3C + internal test suites
- [ ] **Production-ready SCXML engine** with comprehensive feature support  
- [ ] **Industry-leading implementation** comparable to SCION (JavaScript) quality
- [ ] **Zero regressions** in existing functionality
- [ ] **Comprehensive documentation** covering all implemented features

## Conclusion

This implementation plan transforms SC from a **basic state machine library** into a **comprehensive, production-ready SCXML engine** with industry-leading test coverage and W3C compliance. The phased approach ensures continuous delivery of value while managing implementation complexity and risk.

The expected outcome is one of the most complete and well-tested SCXML implementations available in any programming language, positioning SC as the definitive choice for state machine requirements in Elixir applications.

---

*For implementation questions or plan modifications, see the technical architecture details in CLAUDE.md or consult the comprehensive test analysis documentation.*
