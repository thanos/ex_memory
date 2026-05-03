defmodule ExMemory.Capabilities do
  @moduledoc """
  Capability introspection for ExMemory backends.

  Every backend exposes a set of capabilities (atoms) describing what
  operations it supports. This module provides utilities to check and
  assert capabilities.
  """

  @all_capabilities [
    :transactions,
    :vector_search,
    :metadata_filtering,
    :temporal_queries,
    :ann_index,
    :reranking,
    :append_only,
    :snapshots
  ]

  @spec all() :: [atom()]
  def all, do: @all_capabilities

  @spec has?(MapSet.t(), atom()) :: boolean()
  def has?(capabilities, capability) do
    MapSet.member?(capabilities, capability)
  end

  @spec check!(MapSet.t(), atom()) :: :ok | no_return()
  def check!(capabilities, capability) do
    unless MapSet.member?(capabilities, capability) do
      raise "Capability #{inspect(capability)} is not supported by this backend"
    end

    :ok
  end
end
