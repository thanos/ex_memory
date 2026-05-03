defmodule ExMemory.Archive do
  @moduledoc """
  Behaviour for snapshot and time-travel queries over stored data.

  Archives enable point-in-time reconstruction of the memory state,
  supporting audit, debugging, and rollback scenarios.
  """

  @type state :: term()

  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, term()}
  @callback snapshot(state(), label :: String.t()) :: {:ok, term()} | {:error, term()}
  @callback restore(state(), label :: String.t()) :: {:ok, term()} | {:error, term()}
  @callback list_snapshots(state()) :: {:ok, [map()]} | {:error, term()}
  @callback capabilities(state()) :: MapSet.t()
end
