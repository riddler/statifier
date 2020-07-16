defmodule Statifier.MixProject do
  use Mix.Project

  def project do
    [
      app: :statifier_spec,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      docs: [extras: ["README.md"]],
      description: description(),
      # package: package(),
      deps: deps()
    ]
  end

  def description, do: "Statifier Spec Generator"

  # def package do
  #   [
  #     name: :statifier_spec,
  #     maintainers: ["JohnnyT"],
  #     licenses: ["MIT"],
  #     docs: [extras: ["README.md"]],
  #     links: %{"GitHub" => "https://github.com/riddler/statifier-ex"}
  #   ]
  # end

  # # Run "mix help compile.app" to learn about applications.
  # def application do
  #   [
  #     extra_applications: [:logger]
  #   ]
  # end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:liquid, "~> 0.9"},
      {:yaml_elixir, "~> 2.4"}
    ]
  end
end
