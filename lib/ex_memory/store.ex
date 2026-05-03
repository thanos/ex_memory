defmodule ExMemory.Store do
  @moduledoc """
  Behaviour for structured storage of domain objects.

  Implementations must support entities, facts, events, sources, and reflections
  through a unified insert/query/update/delete interface parameterized by resource type.
  """

  @type state :: term()
  @type resource :: :entity | :fact | :event | :source | :reflection

  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, term()}
  @callback insert(state(), struct :: struct()) :: {:ok, struct()} | {:error, term()}
  @callback update(state(), struct :: struct()) :: {:ok, struct()} | {:error, term()}
  @callback query(state(), resource(), filters :: keyword()) ::
              {:ok, [struct()]} | {:error, term()}
  @callback delete(state(), resource(), id :: String.t()) :: {:ok, term()} | {:error, term()}
  @callback transaction(state(), fun :: (state() -> term())) :: {:ok, term()} | {:error, term()}
  @callback capabilities(state()) :: MapSet.t()
end
