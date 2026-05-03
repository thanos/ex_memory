defmodule ExMemory.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/thanos/ex_memory"

  def project do
    [
      app: :ex_memory,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description:
        "A local-first, pluggable, high-level memory system for LLMs and applications — unifying structured facts, temporal events, and semantic retrieval.",
      name: "ExMemory",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:exqlite, "~> 0.19"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Thanos Vassilakis"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: [
        "lib",
        "LICENSE",
        "README.md",
        "CHANGELOG.md",
        "mix.exs",
        ".formatter.exs"
      ]
    ]
  end

  defp docs do
    [
      main: "ExMemory",
      source_url: @source_url,
      extras: [
        "docs/learning/phase_01_memory_systems.md",
        "docs/learning/phase_01_vector_dimensions.md",
        "docs/learning/phase_01_storage_design.md",
        "docs/learning/phase_01_code_walkthrough.md",
        "docs/design/architecture.md",
        "docs/design/storage.md",
        "docs/design/vector.md",
        "docs/design/capabilities.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        "Learning Guides": ~r/docs\/learning\//,
        "Design Docs": ~r/docs\/design\//
      ],
      groups_for_modules: [
        "Domain Models": [
          ExMemory.Entity,
          ExMemory.Fact,
          ExMemory.Event,
          ExMemory.Source,
          ExMemory.Reflection,
          ExMemory.Chunk
        ],
        Behaviours: [
          ExMemory.Store,
          ExMemory.VectorIndex,
          ExMemory.Retriever,
          ExMemory.Embedder,
          ExMemory.EventArchive,
          ExMemory.Archive
        ],
        "SQLite Backends": [
          ExMemory.Store.SQLite,
          ExMemory.VectorIndex.SQLite
        ],
        "Query & Results": [
          ExMemory.Query,
          ExMemory.Result
        ],
        Capabilities: [
          ExMemory.Capabilities
        ]
      ]
    ]
  end
end
