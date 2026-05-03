defmodule ExMemory.EventArchive do
  @moduledoc """
  Behaviour for append-only event log storage.

  Event archives are optimized for high-throughput event ingestion
  and time-range retrieval. They do not support updates or deletes.
  """

  @type state :: term()

  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, term()}
  @callback append(state(), event :: ExMemory.Event.t()) ::
              {:ok, ExMemory.Event.t()} | {:error, term()}
  @callback query(state(), filters :: keyword()) :: {:ok, [ExMemory.Event.t()]} | {:error, term()}
  @callback capabilities(state()) :: MapSet.t()
end
