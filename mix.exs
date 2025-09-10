defmodule Statifier.MixProject do
  use Mix.Project

  @app :statifier
  @version "1.9.0"
  @description "StateCharts for Elixir with W3C compliance"
  @source_url "https://github.com/riddler/statifier"
  @deps [
    # Documentation (split out to reduce compile time in dev/test)
    {:ex_doc, "~> 0.31", only: :docs, runtime: false},

    # Development, Test, Local
    {:castore, "~> 1.0", only: [:dev, :test]},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:excoveralls, "~> 0.18", only: :test},

    # Runtime
    {:jason, "~> 1.4"},
    {:predicator, "~> 3.5"},
    {:saxy, "~> 1.6"},
    {:uxid, "~> 2.1"}
  ]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      config_path: "config/config.exs",
      deps: @deps,
      docs: docs(),
      description: @description,
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.cobertura": :test,
        "coveralls.github": :test,
        docs: :docs
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit],
        warnings: [:unknown]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      name: @app,
      files: ~w(lib/statifier* mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Riddler Team"]
    ]
  end

  defp docs do
    [
      name: "Statifier",
      source_ref: "v#{@version}",
      canonical: "https://hexdocs.pm/statifier",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      main: "readme"
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]
end
