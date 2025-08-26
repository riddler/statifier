defmodule SC do
  @moduledoc """
  Documentation for `SC`.
  """

  alias Statifier.{Interpreter, Parser.SCXML, Validator}

  defdelegate parse(source_string), to: SCXML
  defdelegate validate(document), to: Validator
  defdelegate interpret(document), to: Interpreter, as: :initialize
end
