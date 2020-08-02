defmodule Statifier.Codec do
  @moduledoc """
  Codecs parse statechart definitions into valid `Statifier.Schema`s

  Buil in Codecs:
  * scxml - `Statifier.Codec.SCXML`
  * yaml - `Statifier.Codec.YAML`
  """
  alias Statifier.Schema

  @callback parse(Path.t()) :: {:ok, Schema.t()} | {:error, any()}
end
