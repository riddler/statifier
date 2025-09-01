# SCXML Implementation Plan v1.8 - Completing Core SCXML

## Executive Summary

Statifier has achieved exceptional SCXML compliance with 89.2% test pass rate and 22/25 core features implemented. This plan outlines the path to complete core SCXML specification compliance and advanced feature support.

**Current Status**: Production-ready SCXML engine with comprehensive feature set
**Target**: 95%+ test coverage with complete core SCXML specification support
**Timeline**: 8-12 weeks across 3 phases

## Phase 4: Complete Core SCXML Features (2-3 weeks)

### Priority 1: Internal Transitions (Week 1)

**Feature**: `internal_transitions`
**Status**: :unsupported → :supported
**Impact**: 5-10 tests, critical for SCXML compliance
**Complexity**: Medium

#### Implementation Steps

1. **Parser Enhancement** (1-2 days)

   ```elixir
   # Extend transition parsing to handle type="internal"
   # File: lib/statifier/parser/scxml/element_builder.ex
   def build_transition(attributes, location, xml_string, _element_counts) do
     attrs_map = attributes_to_map(attributes)
     type = Map.get(attrs_map, "type", "external")  # Default to external
     
     %Transition{
       type: type,  # Add type field to Transition struct
       # ... existing fields
     }
   end
   ```

2. **Data Structure Update** (0.5 days)

   ```elixir
   # File: lib/statifier/transition.ex
   defstruct [
     :type,  # Add type field: "internal" | "external" | nil
     # ... existing fields
   ]
   ```

3. **Interpreter Logic** (2-3 days)

   ```elixir
   # File: lib/statifier/interpreter.ex
   defp execute_transition_set(transitions, state_chart) do
     {internal_transitions, external_transitions} = 
       Enum.split_with(transitions, &(&1.type == "internal"))
     
     # Execute internal transitions without exit/entry
     state_chart = execute_internal_transitions(internal_transitions, state_chart)
     
     # Execute external transitions with full exit/entry logic
     execute_external_transitions(external_transitions, state_chart)
   end
   
   defp execute_internal_transitions(transitions, state_chart) do
     # Execute transition actions without changing state configuration
     Enum.reduce(transitions, state_chart, fn transition, acc ->
       ActionExecutor.execute_transition_actions(transition, acc)
     end)
   end
   ```

4. **Testing & Validation** (1 day)
   - Update feature detector to mark as :supported
   - Run affected tests to verify implementation
   - Add specific internal transition test cases

**Estimated Effort**: 4-5 days
**Risk**: Low - clear specification, isolated changes

### Priority 2: Enhanced Partial Features (Week 2)

**Features**: `send_content_elements`, `send_param_elements`, `send_delay_expressions`
**Status**: :partial → :supported
**Impact**: Improve reliability of existing functionality

#### Send Content Elements Enhancement

1. **Content Data Processing** (1-2 days)

   ```elixir
   # File: lib/statifier/actions/send_action.ex
   defp build_content_data(content, state_chart) do
     cond do
       content.expr != nil ->
         # Enhanced expression evaluation with better error handling
         case ValueEvaluator.evaluate_value(content.expr, state_chart) do
           {:ok, value} -> serialize_content_value(value)
           {:error, reason} -> 
             LogManager.warn(state_chart, "Content expression evaluation failed: #{reason}")
             ""
         end
       
       content.content != nil ->
         # Direct content text - ensure proper encoding
         String.trim(content.content)
       
       true ->
         ""
     end
   end
   
   defp serialize_content_value(value) when is_binary(value), do: value
   defp serialize_content_value(value) when is_map(value), do: Jason.encode!(value)
   defp serialize_content_value(value), do: inspect(value)
   ```

2. **Parameter Processing Enhancement** (1-2 days)
   - Improve parameter name validation
   - Better handling of complex parameter values
   - Enhanced error reporting for param evaluation failures

3. **Delay Expression Processing** (1 day)

   ```elixir
   defp evaluate_delay(send_action, state_chart) do
     cond do
       send_action.delay != nil ->
         validate_delay_format(send_action.delay)
       
       send_action.delay_expr != nil ->
         case ValueEvaluator.evaluate_value(send_action.delay_expr, state_chart) do
           {:ok, value} -> 
             delay_value = to_string(value)
             validate_delay_format(delay_value)
           {:error, reason} ->
             LogManager.warn(state_chart, "Delay expression evaluation failed: #{reason}")
             "0s"
         end
       
       true ->
         "0s"
     end
   end
   
   defp validate_delay_format(delay) do
     # Validate delay format (e.g., "5s", "100ms", "2m")
     # Return normalized delay or "0s" for invalid formats
   end
   ```

**Estimated Effort**: 4-5 days
**Risk**: Low - building on existing implementation

### Phase 4 Deliverables

- ✅ Internal transitions fully implemented and tested
- ✅ Send element features moved from :partial to :supported
- ✅ Feature detector updated with new support status
- ✅ Test coverage improvement: 89.2% → ~92-93%
- ✅ Comprehensive test validation of all changes

## Phase 5: Advanced Scripting Support (4-6 weeks)

### Script Elements Implementation

**Feature**: `script_elements`
**Status**: :unsupported → :supported  
**Impact**: 9 tests, enables dynamic SCXML behavior
**Complexity**: High

#### Implementation Approach

1. **JavaScript Engine Integration** (Week 1-2)

   ```elixir
   # New module: lib/statifier/script_engine.ex
   defmodule Statifier.ScriptEngine do
     @moduledoc """
     JavaScript execution engine for SCXML script elements.
     Uses a sandboxed JavaScript environment for security.
     """
     
     def execute_script(script_content, datamodel, state_chart) do
       context = build_script_context(datamodel, state_chart)
       
       case JSEngine.eval(script_content, context) do
         {:ok, result, updated_context} ->
           updated_datamodel = extract_datamodel_changes(updated_context, datamodel)
           {:ok, updated_datamodel}
         
         {:error, reason} ->
           {:error, "Script execution failed: #{reason}"}
       end
     end
     
     defp build_script_context(datamodel, state_chart) do
       # Build JavaScript context with SCXML variables
       # Include _event, _sessionid, etc.
     end
   end
   ```

2. **Parser Integration** (Week 1)

   ```elixir
   # Add script parsing to element builder
   def build_script(attributes, location, xml_string, element_counts) do
     content = extract_script_content(xml_string, location)
     
     %ScriptAction{
       content: content,
       source_location: location
     }
   end
   ```

3. **Action Execution Integration** (Week 2)

   ```elixir
   # Add script execution to ActionExecutor
   def execute_action(%ScriptAction{} = script, state_chart) do
     case ScriptEngine.execute_script(script.content, state_chart.datamodel, state_chart) do
       {:ok, updated_datamodel} ->
         %{state_chart | datamodel: updated_datamodel}
       
       {:error, reason} ->
         LogManager.error(state_chart, "Script execution error: #{reason}")
         # Add error.execution event to internal queue
         add_error_event(state_chart, reason)
     end
   end
   ```

4. **Security & Sandboxing** (Week 3-4)
   - Implement secure JavaScript execution environment
   - Prevent access to sensitive system resources
   - Timeout mechanisms for long-running scripts
   - Memory usage limitations

**Estimated Effort**: 4-5 weeks
**Risk**: Medium-High - Security concerns, external dependencies

#### Alternative: Limited Script Support

For faster implementation, consider limited script support:

```elixir
# Simple expression-based scripting instead of full JavaScript
defmodule Statifier.SimpleScriptEngine do
  def execute_script(script_content, datamodel, _state_chart) do
    # Parse simple assignment statements like:
    # "counter = counter + 1"
    # "result = condition ? value1 : value2"
    
    case parse_simple_script(script_content) do
      {:assignment, variable, expression} ->
        case ValueEvaluator.evaluate_value(expression, build_context(datamodel)) do
          {:ok, value} ->
            {:ok, Map.put(datamodel, variable, value)}
          {:error, reason} ->
            {:error, reason}
        end
      
      {:unsupported, _} ->
        {:error, "Complex script features not supported"}
    end
  end
end
```

**Estimated Effort**: 1-2 weeks
**Risk**: Low - builds on existing expression evaluation

## Phase 6: External Integration Features (6-8 weeks)

### Invoke Elements Implementation

**Feature**: `invoke_elements`
**Status**: :unsupported → :supported
**Impact**: Complete SCXML specification compliance
**Complexity**: Very High

#### Implementation Architecture

1. **Invoke Infrastructure** (Week 1-2)

   ```elixir
   defmodule Statifier.InvokeManager do
     @moduledoc """
     Manages external process invocation and lifecycle.
     """
     
     def invoke_process(invoke_spec, state_chart) do
       case invoke_spec.type do
         "http" -> HTTPInvoker.invoke(invoke_spec, state_chart)
         "scxml" -> SCXMLInvoker.invoke(invoke_spec, state_chart) 
         "elixir" -> ElixirInvoker.invoke(invoke_spec, state_chart)
         _ -> {:error, "Unsupported invoke type: #{invoke_spec.type}"}
       end
     end
   end
   ```

2. **HTTP Invoker** (Week 2-3)

   ```elixir
   defmodule Statifier.HTTPInvoker do
     def invoke(invoke_spec, state_chart) do
       # HTTP request handling
       # Response processing
       # Event generation based on responses
     end
   end
   ```

3. **SCXML Nested Invoker** (Week 3-4)

   ```elixir
   defmodule Statifier.SCXMLInvoker do
     def invoke(invoke_spec, state_chart) do
       # Create nested SCXML interpreter
       # Event forwarding between parent and child
       # Lifecycle management
     end
   end
   ```

4. **Lifecycle Management** (Week 4-5)
   - Process cleanup on state exit
   - Event forwarding and response handling
   - Error handling and timeout management

**Estimated Effort**: 6-7 weeks
**Risk**: High - Complex external integration, many edge cases

### Additional Features

1. **finalize_elements**: Cleanup logic for invoke termination
2. **cancel_elements**: Cancel delayed send events
3. **donedata_elements**: Final state data propagation

**Estimated Effort**: 1-2 weeks each
**Risk**: Medium - depends on invoke implementation

## Success Metrics & Validation

### Phase 4 Success Criteria

- ✅ Internal transitions: All related tests passing
- ✅ Enhanced partial features: Improved reliability and error handling
- ✅ Test coverage: 92-93% (up from 89.2%)
- ✅ Feature detector: Updated support status
- ✅ No regressions in existing functionality

### Phase 5 Success Criteria

- ✅ Script elements: Basic script execution working
- ✅ Security: Sandboxed execution environment
- ✅ Integration: Scripts can modify datamodel safely
- ✅ Test coverage: 94-95%

### Phase 6 Success Criteria

- ✅ Invoke elements: External process integration
- ✅ Complete SCXML specification support
- ✅ Test coverage: 97-98%
- ✅ Production-ready external integration

## Risk Mitigation

### High-Risk Areas

1. **Script Security**: Implement proper sandboxing from the start
2. **Invoke Complexity**: Start with simple HTTP invoker, add features incrementally  
3. **External Dependencies**: Minimize third-party dependencies where possible
4. **Performance Impact**: Profile and optimize each phase

### Fallback Strategies

1. **Limited Script Support**: Implement expression-based scripting if full JavaScript proves too complex
2. **Phased Invoke**: Implement HTTP-only invoke first, add other types later
3. **Progressive Enhancement**: Each feature should work independently

## Timeline Summary

- **Phase 4** (2-3 weeks): Complete core SCXML → 92-93% test coverage
- **Phase 5** (4-6 weeks): Advanced scripting → 94-95% test coverage  
- **Phase 6** (6-8 weeks): External integration → 97-98% test coverage

**Total Timeline**: 12-17 weeks for complete SCXML specification compliance

## Conclusion

This plan completes the transformation of Statifier from a basic state machine library into a comprehensive, industry-leading SCXML engine. The phased approach ensures:

1. **Immediate Value**: Phase 4 provides quick wins with core SCXML completion
2. **Manageable Complexity**: Each phase builds on previous work
3. **Risk Management**: High-risk features (scripts, invoke) are tackled with proper preparation
4. **Production Quality**: Emphasis on security, testing, and reliability throughout

The implementation maintains Statifier's strengths (clean architecture, comprehensive testing, W3C compliance) while adding the final features needed for complete SCXML specification support.
