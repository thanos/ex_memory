defmodule ExMemory.VectorIndex do
  @moduledoc """
  Behaviour for vector storage and similarity search.

  Implementations manage embedding storage and execute similarity queries.
  They receive `ExMemory.Query` structs and return `ExMemory.Result` structs.
  """

  @type state :: term()

  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, term()}
  @callback insert(state(), embedding :: map()) :: {:ok, map()} | {:error, term()}
  @callback query(state(), query :: ExMemory.Query.t()) ::
              {:ok, [ExMemory.Result.t()]} | {:error, term()}
  @callback delete(state(), id :: String.t()) :: {:ok, term()} | {:error, term()}
  @callback capabilities(state()) :: MapSet.t()
end
