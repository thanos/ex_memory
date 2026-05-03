defmodule ExMemory.Entity do
  @moduledoc """
  Represents a discrete thing in the memory system — a person, concept, object, or any
  named referent that facts and events can attach to.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          name: String.t() | nil,
          metadata: map(),
          source_id: String.t() | nil,
          inserted_at: String.t() | nil,
          updated_at: String.t() | nil
        }

  @enforce_keys [:id, :type]
  defstruct [:id, :type, :name, :source_id, inserted_at: nil, updated_at: nil, metadata: %{}]
end
