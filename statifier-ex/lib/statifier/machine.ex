defmodule Statifier.Machine do
  @moduledoc """
  A reactive system.

  This corresponds to the SCXML Interpreter (also called SCXML Processor)
  """

  alias Statifier.{Statechart}

  # This allows code to use the name of the module instead of __MODULE__
  alias __MODULE__

  # ID of a State
  @type state_id :: String.t()

  # The id(s) of the initial state(s) for the document.
  # If not specified, the first child state in document order is used.
  @type configuration :: [state_id]

  @type t :: %Machine{
          statechart: Statechart.t(),
          configuration: configuration
        }

  defstruct statechart: nil,
            configuration: []

  def interpret(%Machine{} = sc) do
    sc
    # if not valid(doc): failWithError()
    # expandScxmlSource(doc)
    # configuration = new OrderedSet()
    # statesToInvoke = new OrderedSet()
    # internalQueue = new Queue()
    # externalQueue = new BlockingQueue()
    # historyValue = new HashTable()
    # datamodel = new Datamodel(doc)
    # if doc.binding == "early":
    #     initializeDatamodel(datamodel, doc)
    # running = true
    # executeGlobalScriptElement(doc)
    # enterStates([doc.initial.transition])
    # mainEventLoop()
  end

  def main_event_loop() do
    # while running:
    #   enabledTransitions = null
    #   macrostepDone = false
    #   # Here we handle eventless transitions and transitions
    #   # triggered by internal events until macrostep is complete
    #   while running and not macrostepDone:
    #     enabledTransitions = selectEventlessTransitions()
    #     if enabledTransitions.isEmpty():
    #       if internalQueue.isEmpty():
    #         macrostepDone = true
    #       else:
    #         internalEvent = internalQueue.dequeue()
    #         datamodel["_event"] = internalEvent
    #         enabledTransitions = selectTransitions(internalEvent)
    #     if not enabledTransitions.isEmpty():
    #         microstep(enabledTransitions.toList())
    #   # either we're in a final state, and we break out of the loop
    #   if not running:
    #     break
    #   # or we've completed a macrostep, so we start a new macrostep by
    #   # waiting for an external event
    #   # Here we invoke whatever needs to be invoked. The implementation
    #   # of 'invoke' is platform-specific
    #   for state in statesToInvoke.sort(entryOrder):
    #     for inv in state.invoke.sort(documentOrder):
    #       invoke(inv)
    #   statesToInvoke.clear()
    #   # Invoking may have raised internal error events and we iterate
    #   # to handle them
    #   if not internalQueue.isEmpty():
    #     continue
    #   # A blocking wait for an external event.  Alternatively,
    #   # if we have been invoked our parent session also might cancel us.
    #   # The mechanism for this is platform specific, but here we assume
    #   # it’s a special event we receive
    #   externalEvent = externalQueue.dequeue()
    #   if isCancelEvent(externalEvent):
    #     running = false
    #     continue
    #   datamodel["_event"] = externalEvent
    #   for state in configuration:
    #     for inv in state.invoke:
    #       if inv.invokeid == externalEvent.invokeid:
    #         applyFinalize(inv, externalEvent)
    #       if inv.autoforward:
    #         send(inv.id, externalEvent)
    #   enabledTransitions = selectTransitions(externalEvent)
    #   if not enabledTransitions.isEmpty():
    #       microstep(enabledTransitions.toList())
    # # End of outer while running loop.  If we get here, we have reached
    # # a top-level final state or have been cancelled
    # exitInterpreter()
  end

  def exit_interpreter() do
    # statesToExit = configuration.toList().sort(exitOrder)
    # for s in statesToExit:
    #   for content in s.onexit.sort(documentOrder):
    #     executeContent(content)
    #   for inv in s.invoke:
    #     cancelInvoke(inv)
    #   configuration.delete(s)
    #     if isFinalState(s) and isScxmlElement(s.parent):
    #       returnDoneEvent(s.donedata)
  end
end

# function selectEventlessTransitions():
#     enabledTransitions = new OrderedSet()
#     atomicStates = configuration.toList().filter(isAtomicState).sort(documentOrder)
#     for state in atomicStates:
#         loop: for s in [state].append(getProperAncestors(state, null)):
#             for t in s.transition.sort(documentOrder):
#                 if not t.event and conditionMatch(t): 
#                     enabledTransitions.add(t)
#                     break loop
#     enabledTransitions = removeConflictingTransitions(enabledTransitions)
#     return enabledTransitions
# 
# function selectTransitions(event):
#     enabledTransitions = new OrderedSet()
#     atomicStates = configuration.toList().filter(isAtomicState).sort(documentOrder)
#     for state in atomicStates:
#         loop: for s in [state].append(getProperAncestors(state, null)):
#             for t in s.transition.sort(documentOrder):
#                 if t.event and nameMatch(t.event, event.name) and conditionMatch(t):
#                     enabledTransitions.add(t)
#                     break loop
#     enabledTransitions = removeConflictingTransitions(enabledTransitions)
#     return enabledTransitions
# 
# function removeConflictingTransitions(enabledTransitions):
#     filteredTransitions = new OrderedSet()
#     //toList sorts the transitions in the order of the states that selected them
#     for t1 in enabledTransitions.toList():
#         t1Preempted = false
#         transitionsToRemove = new OrderedSet()
#         for t2 in filteredTransitions.toList():
#             if computeExitSet([t1]).hasIntersection(computeExitSet([t2])):
#                 if isDescendant(t1.source, t2.source):
#                     transitionsToRemove.add(t2)
#                 else: 
#                     t1Preempted = true
#                     break
#         if not t1Preempted:
#             for t3 in transitionsToRemove.toList():
#                 filteredTransitions.delete(t3)
#             filteredTransitions.add(t1)
# 
#     return filteredTransitions
# 
# procedure microstep(enabledTransitions):
#     exitStates(enabledTransitions)
#     executeTransitionContent(enabledTransitions)
#     enterStates(enabledTransitions)
# 
# procedure exitStates(enabledTransitions):
#     statesToExit = computeExitSet(enabledTransitions)           
#     for s in statesToExit:
#         statesToInvoke.delete(s)
#     statesToExit = statesToExit.toList().sort(exitOrder)
#     for s in statesToExit:
#         for h in s.history:
#             if h.type == "deep":
#                 f = lambda s0: isAtomicState(s0) and isDescendant(s0,s) 
#             else:
#                 f = lambda s0: s0.parent == s
#             historyValue[h.id] = configuration.toList().filter(f)
#     for s in statesToExit:
#         for content in s.onexit.sort(documentOrder):
#             executeContent(content)
#         for inv in s.invoke:
#             cancelInvoke(inv)
#         configuration.delete(s)
# 
# function computeExitSet(transitions)
#     statesToExit = new OrderedSet
#     for t in transitions:
#         if t.target:
#             domain = getTransitionDomain(t)
#             for s in configuration:
#                 if isDescendant(s,domain):
#                     statesToExit.add(s)
#     return statesToExit   
# 
# 
# procedure enterStates(enabledTransitions):
#     statesToEnter = new OrderedSet()
#     statesForDefaultEntry = new OrderedSet()
#     // initialize the temporary table for default content in history states
#     defaultHistoryContent = new HashTable() 
#     computeEntrySet(enabledTransitions, statesToEnter,
#                     statesForDefaultEntry, defaultHistoryContent) 
#     for s in statesToEnter.toList().sort(entryOrder):
#         configuration.add(s)
#         statesToInvoke.add(s)
#         if binding == "late" and s.isFirstEntry:
#             initializeDataModel(datamodel.s,doc.s)
#             s.isFirstEntry = false
#         for content in s.onentry.sort(documentOrder):
#             executeContent(content)
#         if statesForDefaultEntry.isMember(s):
#             executeContent(s.initial.transition)
#         if defaultHistoryContent[s.id]:
#             executeContent(defaultHistoryContent[s.id]) 
#         if isFinalState(s):
#             if isSCXMLElement(s.parent):
#                 running = false
#             else:
#                 parent = s.parent
#                 grandparent = parent.parent
#                 internalQueue.enqueue(
#                   new Event("done.state." + parent.id, s.donedata))
#                 if isParallelState(grandparent):
#                     if getChildStates(grandparent).every(isInFinalState):
#                         internalQueue.enqueue(
#                           new Event("done.state." + grandparent.id))
# 
# 
# procedure computeEntrySet(transitions, statesToEnter,
#                                statesForDefaultEntry, defaultHistoryContent)
#     for t in transitions:
#         for s in t.target:
#             addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,
#                                        defaultHistoryContent) 
#         ancestor = getTransitionDomain(t) 
#         for s in getEffectiveTargetStates(t)):            
#             addAncestorStatesToEnter(s, ancestor, statesToEnter,
#                                      statesForDefaultEntry, defaultHistoryContent)
# 
# procedure addDescendantStatesToEnter(state,statesToEnter,statesForDefaultEntry,
#                                           defaultHistoryContent):
#     if isHistoryState(state):
#         if historyValue[state.id]:
#             for s in historyValue[state.id]:
#                 addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,
#                                            defaultHistoryContent)
#             for s in historyValue[state.id]:
#                 addAncestorStatesToEnter(s, state.parent, statesToEnter,
#                                          statesForDefaultEntry, defaultHistoryContent)
#         else:
#             defaultHistoryContent[state.parent.id] = state.transition.content
#             for s in state.transition.target:
#                 addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,
#                                            defaultHistoryContent)
#             for s in state.transition.target:     
#                 addAncestorStatesToEnter(s, state.parent, statesToEnter,
#                                          statesForDefaultEntry, defaultHistoryContent)
#     else:
#         statesToEnter.add(state)
#         if isCompoundState(state):
#             statesForDefaultEntry.add(state)
#             for s in state.initial.transition.target:
#                 addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,
#                                            defaultHistoryContent)
#             for s in state.initial.transition.target:    
#                 addAncestorStatesToEnter(s, state, statesToEnter,
#                                          statesForDefaultEntry, defaultHistoryContent)
#         else:
#             if isParallelState(state):
#                 for child in getChildStates(state):
#                     if not statesToEnter.some(lambda s: isDescendant(s,child)):
#                         addDescendantStatesToEnter(child,statesToEnter,statesForDefaultEntry,
#                                                    defaultHistoryContent) 
# 
# 
# procedure addAncestorStatesToEnter(state, ancestor, statesToEnter,
#                                         statesForDefaultEntry, defaultHistoryContent)
#     for anc in getProperAncestors(state,ancestor):
#         statesToEnter.add(anc)
#         if isParallelState(anc):
#             for child in getChildStates(anc):
#                 if not statesToEnter.some(lambda s: isDescendant(s,child)):
#                     addDescendantStatesToEnter(child,statesToEnter,statesForDefaultEntry,
#                                                defaultHistoryContent) 
# 
# function isInFinalState(s):
#     if isCompoundState(s):
#         return getChildStates(s).some(lambda s: isFinalState(s) and configuration.isMember(s))
#     elif isParallelState(s):
#         return getChildStates(s).every(isInFinalState)
#     else:
#         return false
# 
# function getTransitionDomain(t)
#     tstates = getEffectiveTargetStates(t)
#     if not tstates:
#         return null
#     elif t.type == "internal" and isCompoundState(t.source) and
#           tstates.every(lambda s: isDescendant(s,t.source)):
#         return t.source
#     else:
#         return findLCCA([t.source].append(tstates))
# 
# 
# function findLCCA(stateList):
#     for anc in getProperAncestors(stateList.head(),null).filter(isCompoundStateOrScxmlElement):
#         if stateList.tail().every(lambda s: isDescendant(s,anc)):
#             return anc
# 
# 
# function getEffectiveTargetStates(transition)
#     targets = new OrderedSet()
#     for s in transition.target
#         if isHistoryState(s):
#             if historyValue[s.id]:
#                 targets.union(historyValue[s.id])
#             else:
#                 targets.union(getEffectiveTargetStates(s.transition))
#         else:
#             targets.add(s)
#     return targets
# 
# 
# 
# #### `function` getProperAncestors(state1, state2)
# 
# If state2 is null, returns the set of all ancestors of state1 in ancestry order (state1's parent followed by the parent's parent, etc. up to an including the &lt;scxml&gt; element). If state2 is non-null, returns in ancestry order the set of all ancestors of state1, up to but not including state2\. (A "proper ancestor" of a state is its parent, or the parent's parent, or the parent's parent's parent, etc.))If state2 is state1's parent, or equal to state1, or a descendant of state1, this returns the empty set.
# 
# #### `function` isDescendant(state1, state2)
# 
# Returns 'true' if state1 is a descendant of state2 (a child, or a child of a child, or a child of a child of a child, etc.) Otherwise returns 'false'.
# 
# #### `function` getChildStates(state1)
# 
# Returns a list containing all &lt;state&gt;, &lt;final&gt;, and &lt;parallel&gt; children of state1.

