# Statifier Examples Implementation Roadmap

## Overview

This document outlines the phased implementation plan for Statifier's examples directory, which demonstrates practical workflow engine capabilities using GenServer-based state machines.

**Last Updated**: January 2025  
**Current Phase**: Phase 2 (Integration Fixes)

---

## ✅ Phase 1: Foundation & Infrastructure (COMPLETE)

**Status**: ✅ Completed with known limitations  
**Timeline**: Completed January 2025

### Delivered

- **Examples project structure** with independent mix.exs
- **CLI interface** (`mix examples.run`, `mix examples.list`)  
- **Purchase Order Approval Workflow** example
  - SCXML workflow definition
  - GenServer StateMachine implementation
  - Business logic callbacks
  - Comprehensive test suite (structure complete)
  - Interactive demo script
- **Documentation** (README files for examples and workflow)

### Known Issues

- **Event data assignment**: SCXML `_event.data.*` expressions not working
- **Condition evaluation**: Amount-based routing conditions failing
- **Tests**: 6/8 tests failing due to data assignment issues

### Key Files

- `examples/mix.exs` - Root configuration
- `examples/lib/examples/cli.ex` - CLI interface
- `examples/approval_workflow/` - Complete workflow example
- `examples/approval_workflow/scxml/purchase_order.xml` - SCXML definition

---

## 🔧 Phase 2: Core Integration Fixes (CURRENT)

**Status**: 🔧 In Progress  
**Timeline**: 1-2 weeks  
**Goal**: Fix event data handling and achieve 100% test pass rate

### Tasks

1. **Debug & Fix Event Data Flow**
   - Investigate StateMachine → SCXML event data passing
   - Fix `_event.data.*` expression evaluation  
   - Ensure proper datamodel updates from events

2. **Fix Condition Evaluation**
   - Debug amount comparison conditions (`amount <= 5000`)
   - Ensure datamodel variables are accessible in conditions
   - Fix transition routing logic

3. **Complete Test Suite**
   - All 8 purchase order tests passing
   - Add integration tests for event data
   - Add tests for error scenarios

4. **Enhanced Logging**
   - Add debug helpers for event data inspection
   - Improve error messages for failed assignments
   - Add datamodel state inspection tools

### Success Criteria

- ✅ All tests passing (8/8)
- ✅ Demo shows correct data values (not "undefined")
- ✅ Proper amount-based routing working

---

## 📚 Phase 3: Additional Workflow Examples

**Status**: 📋 Planned  
**Timeline**: 1-2 weeks  
**Goal**: Demonstrate diverse workflow patterns

### New Examples

#### 1. Customer Onboarding Workflow

- Multi-step registration process
- Email verification states
- Document upload requirements
- Approval/rejection paths
- **Demonstrates**: Sequential processes, timeouts

#### 2. Order Fulfillment Process

- Order placement → Payment → Inventory check
- Parallel shipping and invoicing
- Exception handling (out of stock, payment failed)
- **Demonstrates**: Parallel states, error recovery

#### 3. Support Ticket Routing

- Priority-based routing
- Escalation after timeout
- Assignment to agents
- Resolution tracking
- **Demonstrates**: Timeouts, escalation, assignments

### Deliverables

- 3 new workflow examples with tests
- Documentation for each workflow
- Demo scripts showing key features
- Common patterns library extracted

---

## 🚀 Phase 4: Advanced Features

**Status**: 📋 Planned  
**Timeline**: 2-3 weeks  
**Goal**: Production-ready capabilities

### Features

#### 1. Persistence Layer

- Save/restore workflow state
- Database integration example (Ecto)
- Workflow history tracking
- Audit trails

#### 2. External Integrations

- Webhook notifications
- Email sending (with Bamboo/Swoosh)
- API callbacks
- Message queue integration

#### 3. Supervisor Trees

- DynamicSupervisor for workflow instances
- Fault tolerance examples
- Restart strategies
- Registry for named workflows

#### 4. Performance & Monitoring

- Telemetry integration
- Metrics collection
- Performance benchmarks
- Load testing examples

### Deliverables

- Production deployment guide
- Monitoring setup examples
- Performance tuning guide
- Best practices documentation

---

## 🎯 Phase 5: Advanced Patterns (Optional)

**Status**: 💭 Optional  
**Timeline**: 2 weeks  
**Goal**: Complex workflow patterns

### Advanced Examples

#### 1. Saga Pattern Implementation

- Distributed transactions
- Compensation logic
- Failure recovery

#### 2. BPMN-style Workflows

- Gateways (XOR, AND, OR)
- Subprocess calls
- Message events

#### 3. Human Task Management

- Task assignment
- Delegation patterns
- Deadline management

#### 4. Workflow Versioning

- Migration strategies
- Running multiple versions
- Backward compatibility

---

## 📊 Progress Summary

| Phase | Status | Completion | Notes |
|-------|--------|------------|-------|
| Phase 1: Foundation | ✅ Complete* | 75% | Infrastructure done, data issues remain |
| Phase 2: Integration Fixes | 🔧 Current | 0% | Critical for examples to work properly |
| Phase 3: More Examples | 📋 Planned | 0% | Blocked by Phase 2 |
| Phase 4: Advanced Features | 📋 Planned | 0% | Production readiness |
| Phase 5: Advanced Patterns | 💭 Optional | 0% | Complex scenarios |

## 🎯 Immediate Next Steps

1. **Fix event data assignment** in SCXML transitions
2. **Debug condition evaluation** for routing logic
3. **Update tests** to work with corrected data flow
4. **Document the fix** for future reference

## 📈 Success Metrics

- **Phase 2**: 100% test pass rate, working demo
- **Phase 3**: 4 complete workflow examples  
- **Phase 4**: Production deployment guide with monitoring
- **Phase 5**: Advanced pattern library with 4+ patterns

## 🛠️ Technical Considerations

### Current Architecture

```text
examples/
├── mix.exs                     # Root project config
├── lib/examples/cli.ex         # CLI interface
├── approval_workflow/           # Phase 1 example
│   ├── scxml/                  # SCXML definitions
│   ├── lib/                    # StateMachine implementations
│   └── test/                   # Comprehensive tests
└── [future examples]/           # Phases 3-5
```

### Integration Points

1. **Statifier.StateMachine** - GenServer wrapper
2. **SCXML Processing** - Event data and conditions
3. **Callbacks** - Business logic hooks
4. **Supervision** - OTP patterns

### Testing Strategy

- Unit tests for each workflow
- Integration tests for CLI
- Property-based tests for state transitions
- Performance benchmarks

## 📝 Notes

- Each phase builds on the previous one
- Phase 2 is critical - blocks all subsequent work
- Examples should be production-quality code
- Documentation is as important as implementation
- All examples must include comprehensive tests

## 🔗 Related Documents

- [SCXML Implementation Plan](./SCXML_IMPLEMENTATION_PLAN.md)
- [Examples README](../examples/README.md)
- [Approval Workflow README](../examples/approval_workflow/README.md)
