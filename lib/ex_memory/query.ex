defmodule ExMemory.Query do
  @moduledoc """
  Structured query for vector search.

  Bundles all search parameters into a single struct so that every
  VectorIndex backend receives the same input shape, regardless of
  what it supports internally.
  """

  @type t :: %__MODULE__{
          vector: [float()] | nil,
          top_k: pos_integer(),
          threshold: float() | nil,
          filters: map(),
          rerank: boolean()
        }

  defstruct vector: nil, top_k: 10, threshold: nil, filters: %{}, rerank: false
end
