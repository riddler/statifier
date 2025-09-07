# Changelog

## ✅ Recent Major Completions

### **Secure Invoke System with Centralized Parameters (v1.9.0)**

- **Handler-Based Security** - Replaces dangerous arbitrary function execution with secure handler registration system
- **SCXML Event Compliance** - Generates proper `done.invoke.{id}`, `error.execution`, and `error.communication` events per specification
- **Centralized Parameter Processing** - Unified `<param>` evaluation with strict (InvokeAction) and lenient (SendAction) error handling modes  
- **External Service Integration** - Safe way to integrate SCXML state machines with external services and APIs
- **Complete Test Coverage** - InvokeAction and InvokeHandler modules achieve 100% test coverage
- **Parameter Architecture Refactor** - Consolidated parameter evaluation logic removes code duplication across actions

### **Complete History State Support (v1.4.0)**

- **Shallow History** - Records and restores immediate children of parent states that contain active descendants
- **Deep History** - Records and restores all atomic descendant states within parent states
- **History Tracking** - Complete `Statifier.HistoryTracker` module with efficient MapSet operations
- **History Validation** - Comprehensive `Statifier.Validator.HistoryStateValidator` with W3C specification compliance
- **History Resolution** - Full W3C SCXML compliant history state transition resolution during interpreter execution
- **StateChart Integration** - History tracking integrated into StateChart lifecycle with recording before onexit actions
- **SCION Test Coverage** - Major improvement in SCION history test compliance (5/8 tests now passing)

### **Multiple Transition Target Support (v1.4.0)**

- **Space-Separated Parsing** - Handles `target="state1 state2 state3"` syntax with proper whitespace splitting
- **API Enhancement** - `Statifier.Transition.targets` field (list) replaces `target` field (string) for better readability
- **Validator Updates** - All transition validators updated for list-based target validation with comprehensive testing
- **Parallel State Fixes** - Critical parallel state exit logic improvements with proper W3C SCXML exit set computation
- **SCION Compatibility** - history4b and history5 SCION tests now pass completely with multiple target support

### **SCXML-Compliant Processing Engine**

- **Microstep/Macrostep Execution** - Implements SCXML event processing model with microstep (single transition set execution) and macrostep (series of microsteps until stable)
- **Eventless Transitions** - Transitions without event attributes (called NULL transitions in SCXML spec) that fire automatically upon state entry
- **Exit Set Computation** - Implements W3C SCXML exit set calculation algorithm for determining which states to exit during transitions
- **LCCA Algorithm** - Full Least Common Compound Ancestor computation for accurate transition conflict resolution and exit set calculation
- **Cycle Detection** - Prevents infinite loops with configurable iteration limits (100 iterations default)
- **Parallel Region Preservation** - Proper SCXML exit semantics for transitions within and across parallel regions
- **Optimal Transition Set** - SCXML-compliant transition conflict resolution where child state transitions take priority over ancestors

### **Enhanced Parallel State Support**

- **Cross-Parallel Boundaries** - Proper exit semantics when transitions leave parallel regions
- **Sibling State Management** - Automatic exit of parallel siblings when transitions exit their shared parent  
- **Self-Transitions** - Transitions within parallel regions preserve unaffected parallel regions
- **Parallel Ancestor Detection** - New functions for identifying parallel ancestors and region relationships
- **Enhanced Exit Logic** - All parallel regions properly exited when transitioning to external states

### **Feature-Based Test Validation System**

- **Statifier.FeatureDetector** - Analyzes SCXML documents to detect used features
- **Feature validation** - Tests fail when they depend on unsupported features  
- **False positive prevention** - No more "passing" tests that silently ignore unsupported features
- **Capability tracking** - Clear visibility into which SCXML features are supported

### **Modular Validator Architecture**

- **Statifier.Validator** - Main orchestrator (from 386-line monolith)
- **Statifier.Validator.StateValidator** - State ID validation
- **Statifier.Validator.TransitionValidator** - Transition target validation  
- **Statifier.Validator.InitialStateValidator** - All initial state constraints
- **Statifier.Validator.ReachabilityAnalyzer** - State reachability analysis
- **Statifier.Validator.Utils** - Shared utilities

### **Initial State Elements**

- **Parser support** - `<initial>` elements with `<transition>` children
- **Interpreter logic** - Proper initial state entry via initial elements
- **Comprehensive validation** - Conflict detection, target validation, structure validation
- **Feature detection** - Automatic detection of initial element usage

## Implementation Status

For current feature status and working capabilities, see the main [README](https://github.com/riddler/statifier/blob/main/README.md).