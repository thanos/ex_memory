defmodule ExMemory.Event do
  @moduledoc """
  An episodic memory record — something that happened at a specific time.

  Events are append-only. They are not updated after insertion.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          event_type: String.t(),
          payload: map(),
          occurred_at: String.t(),
          source_id: String.t() | nil,
          metadata: map(),
          inserted_at: String.t() | nil
        }

  @enforce_keys [:id, :event_type, :occurred_at]
  defstruct [
    :id,
    :event_type,
    :occurred_at,
    :source_id,
    inserted_at: nil,
    payload: %{},
    metadata: %{}
  ]
end
