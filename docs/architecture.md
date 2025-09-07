# Architecture

Statifier follows a clean **Parse → Validate → Optimize** architecture with modular components and efficient data structures.

## Core Components

- **`Statifier.Parser.SCXML`** - SAX-based XML parser with location tracking (parse phase)
- **`Statifier.Validator`** - Modular validation orchestrator with focused sub-validators (validate + optimize phases)
- **`Statifier.Validator.HistoryStateValidator`** - Dedicated validator for history state constraints and W3C compliance
- **`Statifier.FeatureDetector`** - SCXML feature detection for test validation and capability tracking
- **`Statifier.Interpreter`** - Synchronous state chart interpreter with compound state and history support
- **`Statifier.StateChart`** - Runtime container with event queues and history tracking
- **`Statifier.HistoryTracker`** - Core history state tracking with efficient MapSet operations
- **`Statifier.Configuration`** - Active state management (leaf states only)
- **`Statifier.Event`** - Event representation with origin tracking

## Data Structures

- **`Statifier.Document`** - Root SCXML document with states, metadata, O(1) lookup maps, and history helper functions
- **`Statifier.State`** - Individual states with transitions, hierarchical nesting, and history type support
- **`Statifier.Transition`** - State transitions with event, conditions, targets (list for multiple target support), and source optimization
- **`Statifier.Data`** - Datamodel elements with IDs and expressions

## Architecture Flow

The implementation follows a clean **Parse → Validate → Optimize** architecture:

```elixir
# 1. Parse Phase: XML → Document structure
{:ok, document} = Statifier.Parser.SCXML.parse(xml_string)

# 2. Validate + Optimize Phase: Check semantics + build lookup maps
{:ok, optimized_document, warnings} = Statifier.Validator.validate(document)

# 3. Interpret Phase: Use optimized document for runtime
{:ok, state_chart} = Statifier.Interpreter.initialize(optimized_document)
```

**Benefits:**

- Parsers focus purely on structure (supports future JSON/YAML parsers)
- Validation catches semantic errors before optimization
- Only valid documents get expensive optimization treatment
- Clear separation of concerns across phases

## Performance Optimizations

### **O(1) State and Transition Lookups**

- **State lookups**: `Document.find_state/2` uses `state_lookup` map for O(1) access
- **Transition lookups**: `Document.get_transitions_from_state/2` uses `transitions_by_source` map
- **Built during validation**: Maps constructed only for valid documents via `Document.build_lookup_maps/1`

### **Compound and Parallel State Entry**

- **Leaf state storage**: `Configuration` stores only leaf states, computes ancestors dynamically
- **Optimized ancestor computation**: `Configuration.active_ancestors/2` uses O(1) document lookups
- **Efficient MapSet operations**: Direct construction vs incremental building where possible
- **History state integration**: `HistoryTracker` uses same O(1) lookups for efficient recording/restoration

### **Parse → Validate → Optimize Flow**

- **SAX-based parsing**: Memory-efficient XML processing with accurate location tracking
- **Modular validation**: Focused sub-validators (StateValidator, TransitionValidator, etc.)
- **Lazy optimization**: Expensive operations only performed on valid documents
- **Source field optimization**: Transitions include source state for faster event processing

This architecture ensures Statifier remains performant while maintaining clean code organization and comprehensive W3C SCXML compliance.
