defmodule Amadeus.MixProject do
  use Mix.Project

  def project do
    [
      app: :amadeus,
      version: "0.1.1",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:gettext] ++ Mix.compilers(),
      releases: [
        amadeus: [
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Amadeus.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:gun, "~> 2.0.0-rc.2", override: true},
      {:nostrum, github: "Kraigie/nostrum", override: true},
      {:nosedrum, "~> 0.3"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:typed_struct, "~> 0.2.1"},
      {:dotenv_parser, "~> 1.2"},

      # More ergonomic queues
      {:qex, "~> 0.5"},
      {:finch, "~> 0.8.2"},
      {:tesla, "~> 1.4"},
      {:jason, ">= 1.0.0"},
      {:snowflake, "~> 1.0.0"},
      {:gettext, ">= 0.0.0"}
    ]
  end
end
