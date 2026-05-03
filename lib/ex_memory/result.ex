defmodule ExMemory.Result do
  @moduledoc """
  A single result from a vector search or retrieval operation.

  Carries the matching record, its similarity score, and any
  metadata produced during the search process.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          score: float(),
          data: map(),
          metadata: map()
        }

  @enforce_keys [:id, :score]
  defstruct [:id, :score, data: %{}, metadata: %{}]
end
