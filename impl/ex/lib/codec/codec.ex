defmodule Statifier.Codec do
  @moduledoc """
  Codecs parse statechart definitions into valid `Statifier.Schema`s

  Buil in Codecs:
  * scxml - `Statifier.Codec.SCXML`
  * yaml - `Statifier.Codec.YAML`
  """
  alias Statifier.Schema

  @callback from_file(Path.t()) :: {:ok, Schema.t()} | {:error, any()}
  @callback parse(String.t()) :: {:ok, Schema.t()} | {:error, any()}
end
