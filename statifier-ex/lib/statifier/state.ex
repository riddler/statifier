defmodule Statifier.State do
  defstruct id: nil,
    type: :atomic,

#          health: :init,
#          success_count: 0,
#          success_threshold: 1


#  defstruct id
#    #[serde(default, skip_serializing_if = "Option::is_none")]
#    pub id: Option<String>,

#    #[serde(default)]
#    pub idx: StateId,

#    #[serde(rename = "type")]
#    pub t: StateType,

#    #[serde(default)]
#    pub on_init: Vec<ExecutableId>,

#    #[serde(default)]
#    pub on_enter: Vec<ExecutableId>,

#    #[serde(default)]
#    pub on_exit: Vec<ExecutableId>,

#    #[serde(default)]
#    pub invocations: Vec<InvocationId>,

#    #[serde(default)]
#    pub parent: StateId,

#    #[serde(default)]
#    pub children: Vec<StateId>,

#    #[serde(default)]
#    pub ancestors: Vec<StateId>,

#    #[serde(default)]
#    pub descendants: Vec<StateId>,

#    #[serde(default)]
#    pub initial: Vec<StateId>,

#    #[serde(default)]
#    pub transitions: Vec<TransitionId>,

#    #[serde(default)]
#    pub has_history: bool,

#    #[serde(default)]
#    pub loc: Location,
#}


  
end
