# Roadmap

The next major areas for development focus on expanding SCXML feature support and improving the developer experience.

## High Priority Features

### **Enhanced Executable Content**

- **`<script>` elements** - Inline JavaScript execution within SCXML documents
- **`<send>` elements** - External event sending with delays and target specification
- **More action types** - Additional executable content per SCXML specification

### **Advanced Transition Types**

- **Internal Transitions** - `type="internal"` transition support for actions without state changes
- **Targetless Transitions** - Transitions without target for pure action execution
- **Conditional Action Execution** - Enhanced conditional logic in executable content

## Medium Priority Features  

### **Developer Experience**

- **Enhanced Error Handling** - Better error messages with precise source location information
- **Performance Benchmarking** - Establish performance baselines and optimize hot paths
- **Enhanced Validation** - More comprehensive SCXML document validation with detailed error reporting

### **Advanced Data Model Support**

- **JavaScript Expression Engine** - Full ECMAScript expression evaluation for complex data manipulation
- **Enhanced Variable Scoping** - Proper variable scoping rules per SCXML specification
- **Type System Integration** - Better integration with Elixir's type system

### **Runtime Enhancements**

- **Dynamic State Machine Modification** - Runtime modification of state machine structure
- **State Machine Composition** - Combining multiple state machines into larger systems
- **Enhanced Event Processing** - More sophisticated event queuing and processing

## Long-term Vision

### **Ecosystem Integration**

- **Phoenix Integration** - First-class Phoenix framework integration for web applications
- **LiveView Components** - State machine-driven LiveView components
- **OTP Supervision** - Better integration with OTP supervision trees

### **Advanced Features**

- **Distributed State Machines** - State machines spanning multiple nodes
- **State Machine Persistence** - Persistent state machine state across application restarts
- **Visual Development Tools** - Graphical state machine design and debugging tools

### **Performance & Scalability**

- **Concurrent State Machine Execution** - Highly concurrent state machine processing
- **Memory Optimization** - Reduced memory footprint for large state machines
- **Incremental Compilation** - Faster state machine compilation and optimization

## Current Focus

Development is currently focused on completing the core SCXML specification compliance while maintaining the clean architecture and high test coverage that makes Statifier reliable for production use.

For current implementation status, see the [Changelog](/changelog).
