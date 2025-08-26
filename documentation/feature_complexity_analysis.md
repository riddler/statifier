# SCXML Feature Implementation Analysis

## Current State

- **Total tests**: 444
- **Passing**: 294 (66.2%)
- **Failing**: 150 (33.8%)
- **Missing features**: 13 unique features blocking 466 feature dependencies

## Missing Features by Impact (High to Low)

### 1. Executable Content (High Impact, Medium Complexity)

These are the most blocking features - they appear in most failing tests:

#### onentry_actions (78 tests blocked)

- Actions executed when entering a state
- Needs parser support for `<onentry>` elements
- Needs interpreter changes to execute actions during state transitions
- Example: `<onentry><log expr="'entering state'" /></onentry>`

#### log_elements (72 tests blocked)

- Simple logging action within executable content
- Medium complexity - needs basic expression evaluation
- Example: `<log expr="'test message'" label="DEBUG" />`

#### onexit_actions (21 tests blocked)

- Actions executed when exiting a state
- Similar complexity to onentry, but during exit phase
- Example: `<onexit><assign location="x" expr="5" /></onexit>`

### 2. Data Model Features (High Impact, High Complexity)

#### data_elements + datamodel (64 tests each blocked)

- Core data storage and manipulation
- High complexity - needs expression evaluation engine
- Requires JavaScript/ECMAScript interpreter integration
- Example: `<data id="counter" expr="0" />`, `<datamodel>...</datamodel>`

#### assign_elements (48 tests blocked)

- Variable assignment within executable content  
- Depends on data model implementation
- Example: `<assign location="counter" expr="counter + 1" />`

### 3. Event Generation (Medium Impact, Medium Complexity)

#### raise_elements (48 tests blocked)

- Generate internal events during execution
- Needs event queue management in interpreter
- Example: `<raise event="timeout" />`

#### send_elements (34 tests blocked)

- Send events (internal or external)
- More complex - needs delay support, target support
- Example: `<send event="timeout" delay="5s" />`

### 4. Advanced State Features (Low-Medium Impact, Medium Complexity)

#### history_states (12 tests blocked)

- Remember previous state when exiting/re-entering compound states
- Needs history tracking in interpreter
- Example: `<history id="hist" type="shallow">...</history>`

#### targetless_transitions (10 tests blocked)

- Transitions that execute actions but don't change state
- Relatively simple - just skip state change logic
- Example: `<transition event="log" cond="true">...</transition>`

#### internal_transitions (5 tests blocked)

- Transitions that don't exit/re-enter the source state
- Medium complexity - changes transition execution logic
- Example: `<transition event="internal" type="internal">...</transition>`

### 5. Advanced Features (Low Impact, Low-Medium Complexity)

#### script_elements (9 tests blocked)

- Inline JavaScript execution
- High complexity due to script evaluation needs
- Example: `<script>counter = 0;</script>`

#### send_idlocation (1 test blocked)

- Dynamic event targeting
- Low priority due to single test impact

## Implementation Priority Recommendations

### Phase 1: Basic Executable Content (Unlocks ~100+ tests)

1. **Parser changes**: Add support for `onentry`, `onexit`, `log`, `raise` elements
2. **Simple expression evaluator**: Handle string literals and basic expressions
3. **Action execution**: Integrate action execution into interpreter transitions
4. **Event queue**: Add internal event generation for `raise` elements

**Estimated effort**: 2-3 weeks
**Tests unlocked**: ~120-140 tests (major improvement)

### Phase 2: Data Model Foundation (Unlocks remaining failing tests)

1. **Data model implementation**: Variable storage and scoping
2. **Expression evaluation**: JavaScript/ECMAScript expression support
3. **Assignment actions**: Variable manipulation via `assign` elements
4. **Enhanced logging**: Expression-based log messages

**Estimated effort**: 4-6 weeks (complex)
**Tests unlocked**: ~100+ additional tests

### Phase 3: Advanced Features (Polish and edge cases)

1. **History states**: State history tracking and restoration
2. **Advanced transitions**: Internal and targetless transitions
3. **Send elements**: External event sending with delays
4. **Script elements**: Full script execution support

**Estimated effort**: 3-4 weeks
**Tests unlocked**: ~20-30 remaining tests

## Technical Architecture Changes Needed

### Parser Enhancements

- Extend `Statifier.Parser.SCXML.Handler` to handle executable content elements
- Add data structures for actions in `Statifier.State` and `Statifier.Document`
- Parse expression attributes and script content

### Interpreter Enhancements  

- Add action execution during state transitions
- Implement data model context/scoping
- Add internal event queue for `raise` events
- Enhance transition logic for internal/targetless transitions

### New Modules Needed

- `Statifier.DataModel` - Variable storage and management
- `Statifier.ExpressionEvaluator` - Expression parsing and evaluation
- `Statifier.ActionExecutor` - Execute onentry/onexit/transition actions
- `Statifier.EventQueue` - Internal event management

## Risk Assessment

**Low Risk**: onentry/onexit actions, log elements, raise elements, targetless transitions
**Medium Risk**: Data model, expression evaluation, history states  
**High Risk**: Script elements, full ECMAScript compatibility, send elements with external targets

## Conclusion

Implementing **Phase 1 (Basic Executable Content)** would provide the highest ROI, unlocking approximately 25-30% more tests with moderate implementation complexity. The data model (Phase 2) is essential for full SCXML compliance but represents the highest complexity challenge.
