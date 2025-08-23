# SCXML Implementation Roadmap

## Executive Summary

Analysis of 444 tests (294 passing, 150 failing) reveals that **13 missing SCXML features** are blocking test suite completion. Implementing **executable content support** would unlock ~80-100 additional tests with moderate complexity, while full **data model support** would unlock the remaining ~50-70 tests but requires significant architectural changes.

## Feature Impact Analysis

### Tier 1: High Impact, Medium Complexity (120+ tests)

1. **onentry_actions** (78 tests) - Execute actions when entering states  
2. **log_elements** (72 tests) - Simple logging within executable content
3. **raise_elements** (48 tests) - Generate internal events
4. **onexit_actions** (21 tests) - Execute actions when exiting states

### Tier 2: High Impact, High Complexity (110+ tests)  

1. **datamodel + data_elements** (64 tests each) - Variable storage and management
2. **assign_elements** (48 tests) - Variable assignment actions

### Tier 3: Medium Impact, Various Complexity (50+ tests)

1. **send_elements** (34 tests) - Event sending with delay support
2. **history_states** (12 tests) - State history preservation  
3. **targetless_transitions** (10 tests) - Actions without state changes
4. **script_elements** (9 tests) - JavaScript execution
5. **internal_transitions** (5 tests) - Non-exit/entry transitions
6. **send_idlocation** (1 test) - Dynamic event targeting

## Required Architecture Changes

### Data Structure Extensions

**SC.State** needs:

```elixir
defstruct [
  # ... existing fields ...
  onentry_actions: [],      # List of executable actions
  onexit_actions: []        # List of executable actions  
]
```

**SC.Transition** needs:

```elixir
defstruct [
  # ... existing fields ...
  actions: [],              # List of executable actions
  type: :external           # :external | :internal
]
```

**New SC.Action** struct:

```elixir
defstruct [
  type: nil,                # :log | :raise | :assign | :send | :script
  expr: nil,                # Expression to evaluate
  attributes: %{}           # Element-specific attributes
]
```

### Parser Extensions

**SC.Parser.SCXML.Handler** needs cases for:

- `onentry` → collect child actions, add to state
- `onexit` → collect child actions, add to state  
- `log` → create log action with expr/label attributes
- `raise` → create raise action with event attribute
- `assign` → create assign action with location/expr
- `send` → create send action with event/delay/target

### Interpreter Enhancements

**SC.Interpreter** execution flow changes:

```elixir
# During state transition execution:
1. Execute onexit_actions of exiting states
2. Execute transition actions  
3. Execute onentry_actions of entering states
4. Process any raised internal events (microstep continuation)
```

### New Modules Required

**SC.ActionExecutor**:

```elixir
def execute_actions(actions, context) do
  Enum.reduce(actions, context, &execute_single_action/2)
end

def execute_single_action(%SC.Action{type: :raise, attributes: %{"event" => event}}, context) do
  # Add event to internal queue
end

def execute_single_action(%SC.Action{type: :log, expr: expr}, context) do  
  # Evaluate expression and log result
end
```

**SC.ExpressionEvaluator** (Phase 2):

```elixir
def evaluate(expr, data_model) do
  # Parse and evaluate JavaScript expressions
  # Return {:ok, value} | {:error, reason}
end
```

**SC.DataModel** (Phase 2):

```elixir
def new(initial_data \\ %{}) do
  # Create new data model context
end

def get(data_model, variable) do
  # Get variable value
end

def set(data_model, variable, value) do
  # Set variable value
end
```

## Implementation Phases

### Phase 1: Basic Executable Content (2-3 weeks)

**Goal**: Unlock ~80-100 tests with raise/onentry/onexit/log support

**Week 1**: Parser extensions

- Add action parsing to SCXML handler
- Extend state/transition data structures  
- Add basic action collection during parsing

**Week 2**: Interpreter integration  

- Implement ActionExecutor with raise/log support
- Integrate action execution into state transitions
- Add internal event queue for raised events

**Week 3**: Testing and refinement

- Test against SCION action tests
- Handle edge cases and error conditions
- Documentation and cleanup

**Expected outcome**: ~66% → ~85% test pass rate

### Phase 2: Data Model (4-6 weeks)

**Goal**: Unlock remaining ~50-70 tests with full variable support

**Weeks 1-2**: Expression evaluation foundation

- Research JavaScript expression parsing options
- Implement basic expression evaluator
- Support variable references and simple operations

**Weeks 3-4**: Data model integration  

- Implement SC.DataModel for variable storage
- Add assign action support
- Integrate with expression evaluator

**Weeks 5-6**: Advanced features

- Enhanced expression support (objects, arrays, functions)
- Integration testing with W3C mandatory tests
- Performance optimization

**Expected outcome**: ~85% → ~95% test pass rate

### Phase 3: Advanced Features (2-3 weeks)

**Goal**: Polish and edge cases for remaining tests

- History state implementation  
- Internal/targetless transition support
- Send element with delay support
- Script element basic support

**Expected outcome**: ~95% → ~98%+ test pass rate

## Risk Assessment & Mitigation

### Technical Risks

**High Risk**: JavaScript expression evaluation

- *Mitigation*: Start with subset of expressions, expand gradually
- *Alternative*: Use Elixir-native expression syntax initially

**Medium Risk**: Action execution ordering and event processing

- *Mitigation*: Follow W3C specification exactly, extensive testing
- *Reference*: SCION implementation patterns

**Low Risk**: Parser extensions, data structure changes

- *Mitigation*: Incremental changes with test coverage

### Integration Risks

**Data model performance**: Variable lookups in tight loops

- *Mitigation*: Optimize after correctness, consider ETS for large datasets

**Memory usage**: Storing parsed actions and expressions  

- *Mitigation*: Profile memory usage, optimize data structures

## Success Metrics

- **Phase 1**: 85%+ test pass rate (from current 66%)
- **Phase 2**: 95%+ test pass rate  
- **Phase 3**: 98%+ test pass rate
- **Code quality**: Maintain current Credo/Dialyzer standards
- **Performance**: No significant regression in transition speed

## Recommended Next Steps

1. **Immediate**: Begin Phase 1 implementation with `raise` element support
2. **Week 1**: Implement basic onentry action execution  
3. **Week 2**: Add log element support for debugging
4. **Month 2**: Start Phase 2 planning and expression evaluation research

This roadmap provides a clear path to dramatically improve SCXML compliance while managing implementation complexity through incremental phases.
