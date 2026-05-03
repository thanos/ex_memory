defmodule ExMemory.Retriever do
  @moduledoc """
  Behaviour for memory retrieval orchestration.

  A retriever coordinates store queries, vector search, and (future) reranking
  to produce the most relevant results for a given query.
  """

  @type state :: term()

  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, term()}
  @callback retrieve(state(), query :: ExMemory.Query.t()) ::
              {:ok, [ExMemory.Result.t()]} | {:error, term()}
  @callback capabilities(state()) :: MapSet.t()
end
