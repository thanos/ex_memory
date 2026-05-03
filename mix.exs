defmodule ExMemory.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_memory,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:exqlite, "~> 0.19"},
      {:jason, "~> 1.4"}
    ]
  end
end
