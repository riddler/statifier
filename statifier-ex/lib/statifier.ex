defmodule Statifier do
  @moduledoc """
  Documentation for Statifier.
  """

  def machine_from_file path do
    {:ok, xmldoc} = File.read Path.expand path
    statechart = Statifier.Scxml.parse_statechart xmldoc
    Statifier.Machine.new statechart
  end
end
