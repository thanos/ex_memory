defmodule ExMemory.Fact do
  @moduledoc """
  A structured SPO (subject-predicate-object) statement with temporal validity.

  Facts are the core of semantic memory. They record what is true (or was true)
  during a specific time window.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          subject: String.t(),
          predicate: String.t(),
          object: String.t(),
          valid_from: String.t() | nil,
          valid_to: String.t() | nil,
          observed_at: String.t() | nil,
          metadata: map(),
          source_id: String.t() | nil,
          inserted_at: String.t() | nil,
          updated_at: String.t() | nil
        }

  @enforce_keys [:id, :subject, :predicate, :object]
  defstruct [
    :id,
    :subject,
    :predicate,
    :object,
    :valid_from,
    :valid_to,
    :observed_at,
    :source_id,
    inserted_at: nil,
    updated_at: nil,
    metadata: %{}
  ]
end
