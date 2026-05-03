defmodule ExMemory.Reflection do
  @moduledoc """
  An LLM-derived insight — a conclusion, summary, pattern, or self-correction
  produced by the model itself.

  Reflections reference the sources they were derived from and carry metadata
  about the reasoning process.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t(),
          source_ids: [String.t()],
          metadata: map(),
          inserted_at: String.t() | nil,
          updated_at: String.t() | nil
        }

  @enforce_keys [:id, :content]
  defstruct [:id, :content, inserted_at: nil, updated_at: nil, source_ids: [], metadata: %{}]
end
