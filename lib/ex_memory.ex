defmodule ExMemory do
  @moduledoc """
  A local-first, pluggable, high-level memory system for LLMs and applications.

  ExMemory unifies structured facts, temporal events, semantic retrieval, and
  agent memory into a single abstraction layer with pluggable storage backends.

  ## Quick Start

      # Initialize a store and vector index (both use SQLite in Phase 1)
      {:ok, store} = ExMemory.Store.SQLite.init(path: "memory.db")
      {:ok, vidx}  = ExMemory.VectorIndex.SQLite.init(path: "memory.db")

      # Insert an entity and a fact about it
      {:ok, alice} = ExMemory.Store.SQLite.insert(store, %ExMemory.Entity{
        id: "e1", type: "person", name: "Alice"
      })
      {:ok, fact} = ExMemory.Store.SQLite.insert(store, %ExMemory.Fact{
        id: "f1", subject: "Alice", predicate: "reports_to", object: "Bob"
      })

      # Store a vector and search
      {:ok, _} = ExMemory.VectorIndex.SQLite.insert(vidx, %{
        id: "emb1", entity_id: "e1", vector: [1.0, 0.0, 0.0], dimension: 3
      })
      {:ok, results} = ExMemory.VectorIndex.SQLite.query(vidx, %ExMemory.Query{
        vector: [0.9, 0.1, 0.0], top_k: 5
      })
  """

  alias ExMemory.{Store, VectorIndex, Query, Result, Capabilities}

  _ = {Store, VectorIndex, Query, Result, Capabilities}
end
