# SCXML `<send>` Element Implementation Plan

## Executive Summary

This document outlines the comprehensive implementation plan for the SCXML `<send>` element in Statifier. The `<send>` element is a critical feature that enables event-based communication within and between state machines, supporting both immediate and delayed event delivery with data payloads.

**Estimated Timeline**: 4-5 weeks across four implementation phases  
**Impact**: Enables 30+ SCION tests and multiple W3C conformance tests  
**Priority**: High - Essential for real-world SCXML applications

## 1. W3C Specification Overview

### 1.1 Purpose

The `<send>` element provides SCXML state machines with the ability to:

- Send events to internal or external destinations
- Schedule delayed event delivery
- Include structured data with events
- Enable inter-session communication
- Interface with external systems via Event I/O Processors

### 1.2 Formal Specification

#### Attributes

| Attribute | Required | Type | Default | Description |
|-----------|----------|------|---------|-------------|
| `event` | No* | NMTOKEN | - | Name of the event to send |
| `eventexpr` | No* | Value Expression | - | Expression evaluating to event name |
| `target` | No | URI | `#_internal` | Destination for the event |
| `targetexpr` | No | Value Expression | - | Expression evaluating to target URI |
| `type` | No | NMTOKEN | `scxml` | Event I/O Processor type |
| `typeexpr` | No | Value Expression | - | Expression evaluating to processor type |
| `id` | No | ID | Auto-generated | Unique identifier for this send |
| `idlocation` | No | Location Expression | - | Variable to store generated ID |
| `delay` | No | Duration | `0s` | Delay before sending (e.g., "500ms", "2s") |
| `delayexpr` | No | Value Expression | - | Expression evaluating to delay duration |
| `namelist` | No | Location List | - | Space-separated list of data model variables |

*Must specify either `event` or `eventexpr`, but not both

#### Child Elements

**`<param>` Element**

```xml
<param name="paramName" expr="expression"/>
<param name="paramName" location="dataModelLocation"/>
```

- Provides key-value pairs to include with the event
- Must specify either `expr` or `location`, not both

**`<content>` Element**

```xml
<content expr="expression"/>
<content>literal content</content>
```

- Specifies inline content as event data
- Can contain either literal content or an expression

#### Constraints

- A `<send>` element may contain either `<param>` elements or a `<content>` element, but not both
- If `namelist` is specified, it cannot be used with `<param>` or `<content>`
- The `id` attribute must be unique within the session

### 1.3 Event I/O Processors

#### SCXML Event I/O Processor (Internal)

- **Type identifier**: `scxml` or `http://www.w3.org/TR/scxml/#SCXMLEventProcessor`
- **Target format**: `#_internal` for same session
- **Behavior**: Places events directly in internal queue for immediate processing

#### Basic HTTP Event I/O Processor

- **Type identifier**: `basichttp` or `http://www.w3.org/TR/scxml/#BasicHTTPEventProcessor`
- **Target format**: Full HTTP/HTTPS URL
- **Behavior**: Sends events as HTTP POST requests

### 1.4 Related Elements

#### `<cancel>` Element

```xml
<cancel sendid="send1"/>
<cancel sendidexpr="getSendId()"/>
```

- Cancels a delayed send operation
- References the send by its ID

## 2. Current System Analysis

### 2.1 Existing Infrastructure

**Available Components**:

- ✅ Action execution framework (`Statifier.Actions.ActionExecutor`)
- ✅ Expression evaluation (`Statifier.ValueEvaluator`, `Statifier.ConditionEvaluator`)
- ✅ Internal event queue management (`Statifier.StateChart`)
- ✅ Data model support (`datamodel` field in StateChart)
- ✅ Parser infrastructure for executable content

**Missing Components**:

- ❌ Event scheduling system for delays
- ❌ Send ID management and tracking
- ❌ Event I/O Processor framework
- ❌ External communication capabilities
- ❌ Cancel action support

### 2.2 Test Coverage Analysis

**SCION Tests** (Currently Failing):

- `actionSend/` - 9 tests for basic send functionality
- `delayedSend/` - 3 tests for delayed event delivery
- `send_data/` - 1 test for data inclusion
- `send_internal/` - 1 test for internal targeting
- `send_idlocation/` - 1 test for ID management

**W3C Tests** (Currently Failing):

- Multiple tests in `mandatory/` that use send for test coordination
- Tests validating error handling and edge cases

## 3. Implementation Design

### 3.1 Architecture Overview

```text
┌─────────────────────┐
│   Parser Layer      │
│  - Parse <send>     │
│  - Parse <cancel>   │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│  Action Executor    │
│  - Execute send     │
│  - Execute cancel   │
└──────────┬──────────┘
           │
┌──────────▼──────────┐     ┌──────────────────┐
│  Send Processor     │────▶│ Event Scheduler  │
│  - Evaluate attrs   │     │ - Delay mgmt     │
│  - Build event      │     │ - Timer control  │
│  - Route to target  │     └──────────────────┘
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ Event I/O Processor │
│  - Internal queue   │
│  - External comm    │
└─────────────────────┘
```

### 3.2 Data Structures

```elixir
defmodule Statifier.Actions.SendAction do
  @moduledoc """
  Represents a <send> element action.
  """
  
  defstruct [
    :event,           # Static event name
    :eventexpr,       # Expression for event name
    :target,          # Static target URI
    :targetexpr,      # Expression for target
    :type,            # Static processor type
    :typeexpr,        # Expression for processor type
    :id,              # Static send ID
    :idlocation,      # Location to store generated ID
    :delay,           # Static delay duration
    :delayexpr,       # Expression for delay
    :namelist,        # Space-separated variable names
    :params,          # List of SendParam structs
    :content,         # SendContent struct
    :source_location  # XML source location
  ]
end

defmodule Statifier.Actions.SendParam do
  @moduledoc """
  Represents a <param> child of <send>.
  """
  
  defstruct [
    :name,      # Parameter name
    :expr,      # Expression for value
    :location,  # Data model location for value
    :source_location
  ]
end

defmodule Statifier.Actions.SendContent do
  @moduledoc """
  Represents a <content> child of <send>.
  """
  
  defstruct [
    :expr,      # Expression for content
    :content,   # Literal content
    :source_location
  ]
end

defmodule Statifier.Actions.CancelAction do
  @moduledoc """
  Represents a <cancel> element action.
  """
  
  defstruct [
    :sendid,     # Static send ID to cancel
    :sendidexpr, # Expression for send ID
    :source_location
  ]
end
```

### 3.3 Event Scheduler Design

```elixir
defmodule Statifier.EventScheduler do
  @moduledoc """
  Manages delayed event delivery using Erlang timers.
  """
  
  use GenServer
  
  @type send_id :: String.t()
  @type timer_ref :: reference()
  
  defstruct [
    sends: %{},      # Map of send_id -> {timer_ref, event_data}
    next_id: 1       # Counter for auto-generated IDs
  ]
  
  # Public API
  
  def schedule_send(scheduler, send_action, delay_ms, callback) do
    # Returns {:ok, send_id}
  end
  
  def cancel_send(scheduler, send_id) do
    # Returns :ok | {:error, :not_found}
  end
  
  def cancel_all_sends(scheduler) do
    # Cleanup on state machine termination
  end
end
```

## 4. Phased Implementation Plan

### Phase 1: Core Internal Send (Week 1)

**Goal**: Implement basic internal event sending without delays

**Scope**:

- Parse `<send>` elements with basic attributes
- Support `event`/`eventexpr` attributes
- Support `target` attribute for internal sends only
- Execute immediate sends during action execution
- Add events to internal queue

**Implementation Tasks**:

1. Add `SendAction` struct and parser support
2. Implement `send_element` case in `ElementBuilder`
3. Add send execution to `ActionExecutor`
4. Create `SendProcessor` module for event building
5. Update `StateChart` to handle internal send events

**Deliverables**:

- [ ] Parser support for `<send>` elements
- [ ] Basic send execution for internal events
- [ ] Unit tests for send parsing and execution
- [ ] Enable basic actionSend SCION tests

**Success Criteria**:

- Can parse `<send event="myEvent" target="#_internal"/>`
- Events appear in internal queue during macrostep
- At least 3 actionSend tests passing

### Phase 2: Delayed Send & Cancellation (Week 2-3)

**Goal**: Add delayed event delivery and cancellation support

**Scope**:

- Parse and evaluate `delay`/`delayexpr` attributes
- Implement `EventScheduler` GenServer
- Support `id`/`idlocation` for send identification
- Parse and execute `<cancel>` elements
- Handle timer lifecycle and cleanup

**Implementation Tasks**:

1. Create `EventScheduler` GenServer
2. Add delay parsing and evaluation
3. Implement send ID generation and management
4. Add `CancelAction` struct and parser support
5. Integrate scheduler with interpreter lifecycle
6. Handle state machine termination cleanup

**Deliverables**:

- [ ] Working event scheduler with timer management
- [ ] Delay attribute support (ms, s, min formats)
- [ ] Cancel action implementation
- [ ] Integration tests for delayed events
- [ ] Enable delayedSend SCION tests

**Success Criteria**:

- Can schedule events with delays like "500ms", "2s"
- Can cancel delayed sends by ID
- All timers cleaned up on state machine termination
- All 3 delayedSend tests passing

### Phase 3: Advanced Data Handling (Week 4)

**Goal**: Complete data inclusion mechanisms

**Scope**:

- Support `namelist` attribute with datamodel
- Parse and process `<param>` elements
- Parse and process `<content>` element
- Build proper `_event.data` structure
- Handle expression evaluation for all data sources

**Implementation Tasks**:

1. Add `SendParam` and `SendContent` structs
2. Parse param and content child elements
3. Implement `namelist` processing
4. Create `SendDataBuilder` module
5. Integrate with `ValueEvaluator` for expressions
6. Build proper event data structure

**Deliverables**:

- [ ] Complete namelist support
- [ ] Param element support (name/expr/location)
- [ ] Content element support (literal and expr)
- [ ] Proper _event.data structure
- [ ] Enable send_data and send_internal tests

**Success Criteria**:

- Can include datamodel variables via namelist
- Can add custom parameters via `<param>`
- Can include content via `<content>`
- Event data accessible in target state conditions
- send_internal test passing

### Phase 4: External Send & Error Handling (Week 5)

**Goal**: Add external communication and robust error handling

**Scope**:

- Design Event I/O Processor behavior
- Implement SCXML Event I/O Processor
- Add error event generation
- Support different target formats
- Optional: Basic HTTP processor

**Implementation Tasks**:

1. Define `EventIOProcessor` behavior
2. Implement `SCXMLEventIOProcessor`
3. Add target URI parsing and validation
4. Generate `error.communication` events
5. Update send processor for processor selection
6. Optional: Implement `HTTPEventIOProcessor`

**Deliverables**:

- [ ] Event I/O Processor framework
- [ ] Target validation and routing
- [ ] Error event generation
- [ ] External send capability
- [ ] Complete test coverage

**Success Criteria**:

- Can route events based on target URI
- Proper error events for invalid targets
- Clean processor abstraction
- Optional: Can send events via HTTP

## 5. Testing Strategy

### 5.1 Unit Tests

**Parser Tests** (`test/statifier/parser/send_parsing_test.exs`):

- Parse send with all attribute combinations
- Parse param and content children
- Parse cancel elements
- Validate parsing errors

**Executor Tests** (`test/statifier/actions/send_executor_test.exs`):

- Execute immediate sends
- Schedule delayed sends
- Cancel scheduled sends
- Build event data correctly

**Scheduler Tests** (`test/statifier/event_scheduler_test.exs`):

- Schedule and deliver events
- Cancel by ID
- Handle concurrent operations
- Cleanup on termination

### 5.2 Integration Tests

**SCION Test Suites**:

- Enable tests progressively by phase
- Track pass rate improvements
- Document any deviations from SCION behavior

**Custom Integration Tests**:

- Complex send scenarios
- Multiple delayed sends
- Cancellation edge cases
- Data model integration

### 5.3 Performance Tests

- Measure scheduling overhead
- Test with many concurrent timers
- Validate memory cleanup
- Benchmark event delivery latency

## 6. Risk Analysis & Mitigation

### 6.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Timer precision issues | High | Medium | Use monotonic time, test on different platforms |
| Memory leaks from timers | High | Low | Proper cleanup, supervision trees |
| Race conditions | High | Medium | Careful state synchronization |
| Complex expression evaluation | Medium | Low | Leverage existing ValueEvaluator |
| External communication failures | Medium | Medium | Proper error handling, timeouts |

### 6.2 Implementation Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Scope creep | Medium | Medium | Strict phase boundaries |
| Test complexity | Low | High | Incremental test enabling |
| Integration issues | Medium | Medium | Early integration testing |
| Performance degradation | High | Low | Continuous benchmarking |

## 7. Dependencies

### 7.1 Internal Dependencies

- `Statifier.ValueEvaluator` - For expression evaluation
- `Statifier.StateChart` - For event queue management
- `Statifier.Actions.ActionExecutor` - For action execution
- `Statifier.Parser.SCXML` - For parsing extensions

### 7.2 External Dependencies

- Erlang timer functions - For delay implementation
- Optional: HTTP client library - For external sends

## 8. Success Metrics

### 8.1 Functional Metrics

- **Phase 1**: 5+ actionSend tests passing
- **Phase 2**: All 3 delayedSend tests passing
- **Phase 3**: send_internal and send_data tests passing
- **Phase 4**: Complete send test coverage

### 8.2 Quality Metrics

- 100% unit test coverage for new modules
- No memory leaks in scheduler
- Sub-millisecond overhead for immediate sends
- Clean timer cleanup on termination

### 8.3 Progress Tracking

| Milestone | Target Date | Success Criteria |
|-----------|------------|------------------|
| Phase 1 Complete | Week 1 | Basic send working |
| Phase 2 Complete | Week 3 | Delays and cancellation |
| Phase 3 Complete | Week 4 | Full data support |
| Phase 4 Complete | Week 5 | External communication |

## 9. Future Enhancements

### 9.1 Advanced Features (Post-MVP)

- Custom Event I/O Processors
- WebSocket event processor
- Message queue integrations (RabbitMQ, Kafka)
- Send pools for rate limiting
- Distributed send across nodes

### 9.2 Performance Optimizations

- Timer wheel for efficient scheduling
- Batch event delivery
- Lazy expression evaluation
- Event compression for external sends

### 9.3 Developer Experience

- Send debugging tools
- Event tracing and visualization
- Metrics and monitoring
- Send replay for testing

## 10. Conclusion

The `<send>` element is a critical feature for real-world SCXML applications, enabling sophisticated event-driven behaviors and external system integration. This phased implementation plan provides a clear path to full W3C compliance while delivering incremental value at each phase.

The implementation leverages Statifier's existing infrastructure while introducing new components for event scheduling and I/O processing. With careful attention to timer management and error handling, this implementation will provide a robust foundation for advanced SCXML applications.

---

*Document Version: 1.0*  
*Last Updated: 2025-08-29*  
*Author: Statifier Development Team*
