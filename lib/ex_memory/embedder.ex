defmodule ExMemory.Embedder do
  @moduledoc """
  Behaviour for text-to-vector embedding.

  An embedder converts text into a fixed-length float array.
  Implementations wrap external embedding services or local models.
  """

  @type state :: term()

  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, term()}
  @callback embed(state(), text :: String.t()) :: {:ok, [float()]} | {:error, term()}
  @callback embed_batch(state(), texts :: [String.t()]) :: {:ok, [[float()]]} | {:error, term()}
  @callback dimensions(state()) :: pos_integer()
end
