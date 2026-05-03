defmodule ExMemory.Source do
  @moduledoc """
  Records the origin of data entering the memory system — a user, an API, an agent,
  a file import, etc.

  Source provenance enables traceability: every Fact, Event, and Entity can be
  traced back to where it came from.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          kind: String.t(),
          identifier: String.t(),
          metadata: map(),
          inserted_at: String.t() | nil,
          updated_at: String.t() | nil
        }

  @enforce_keys [:id, :kind, :identifier]
  defstruct [:id, :kind, :identifier, inserted_at: nil, updated_at: nil, metadata: %{}]
end
