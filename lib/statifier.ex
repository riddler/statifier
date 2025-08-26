defmodule Statifier do
  @moduledoc """
  Documentation for `Statifier`.
  """

  alias Statifier.{Interpreter, Parser.SCXML, Validator}

  defdelegate parse(source_string), to: SCXML
  defdelegate validate(document), to: Validator
  defdelegate interpret(document), to: Interpreter, as: :initialize
end
