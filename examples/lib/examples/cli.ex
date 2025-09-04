defmodule Examples.CLI do
  @moduledoc """
  Command-line interface for running Statifier examples.
  """

  @doc """
  Main entry point for the examples CLI.
  """
  def run(args) do
    case args do
      ["approval_workflow"] -> 
        run_approval_workflow()
      
      ["list"] -> 
        list()
      
      _ -> 
        show_usage()
    end
  end

  @doc """
  List all available examples.
  """
  def list do
    IO.puts """
    📚 Available Statifier Examples:
    
    approval_workflow  - Purchase Order Approval Workflow
                        Demonstrates GenServer-based state machines
                        for business process automation
    
    Usage: mix examples.run <example_name>
    """
  end

  defp run_approval_workflow do
    IO.puts "🚀 Starting Purchase Order Approval Workflow Example..."
    
    # Load the demo script
    demo_path = Path.join([
      __DIR__, "..", "..", "approval_workflow", "examples", "demo.exs"
    ])
    
    if File.exists?(demo_path) do
      Code.eval_file(demo_path)
    else
      IO.puts "❌ Demo file not found: #{demo_path}"
    end
  end

  defp show_usage do
    IO.puts """
    🔧 Statifier Examples CLI
    
    Usage: mix examples.run <command>
    
    Commands:
      approval_workflow  - Run the purchase order approval workflow demo
      list              - List all available examples
    
    Testing:
      mix examples.test  - Run all example tests
    
    """
  end
end