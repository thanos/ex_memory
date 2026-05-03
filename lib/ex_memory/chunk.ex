defmodule ExMemory.Chunk do
  @moduledoc """
  A text segment extracted from a source document for embedding.

  Chunks are the unit of vectorization. Each chunk carries provenance
  (source_id) and positional metadata so it can be mapped back to its origin.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t(),
          source_id: String.t() | nil,
          metadata: map(),
          inserted_at: String.t() | nil,
          updated_at: String.t() | nil
        }

  @enforce_keys [:id, :content]
  defstruct [:id, :content, :source_id, inserted_at: nil, updated_at: nil, metadata: %{}]
end
