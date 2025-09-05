defmodule Examples.MixProject do
  use Mix.Project

  def project do
    [
      app: :statifier_examples,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_paths: ["approval_workflow/test"],
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: [
        "examples.test": :test,
        "examples.run": :dev
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:statifier, path: "../"},
      {:jason, "~> 1.4"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "approval_workflow/lib"]
  defp elixirc_paths(_), do: ["lib", "approval_workflow/lib"]

  defp aliases do
    [
      "examples.test": ["test --include example"],
      "examples.run": &run_examples/1,
      "examples.list": ["run", "-e", "Examples.CLI.list()"]
    ]
  end

  defp run_examples(args) do
    Mix.Task.run("run", ["-e", "Examples.CLI.run(#{inspect(args)})"])
  end
end
