# ExMemory

A local-first, pluggable, high-level memory system for LLMs and applications, written in Elixir.

ExMemory is **not** a vector database, a thin wrapper over storage engines, or a chat memory utility. It is a memory abstraction layer that unifies structured facts, temporal events, semantic retrieval, and agent memory into a single system.

## Why ExMemory?

LLMs are stateless. Every inference call sees only the tokens you send. A memory system solves three problems:

1. **What to remember** — selecting facts, events, and observations worth retaining
2. **How to store it** — organizing stored information for efficient retrieval
3. **How to recall it** — finding the right memories at the right time

Vector databases alone are insufficient. They lose structure, cannot query by time, treat updates as second-class, and offer no transactional guarantees. ExMemory treats vector search as a **subsystem**, not the system.

## Memory Types

| Type | Records | Example |
|------|---------|---------|
| **Episodic** (Event) | What happened, when | `"user logged in at 2024-03-01"` |
| **Semantic** (Fact) | What is true | `"Alice reports to Bob"` |
| **Reflective** (Reflection) | What was derived | `"this user prefers concise answers"` |

Each type has its own access patterns: events are append-mostly, facts support updates and temporal scoping, reflections carry provenance.

## Core Concepts

### Domain Models

ExMemory owns all canonical data models. Backends never define their own.

- **Entity** — a discrete thing (person, concept, object) that facts and events attach to
- **Fact** — an SPO statement (`subject → predicate → object`) with temporal validity (`valid_from` / `valid_to`)
- **Event** — an append-only record of something that happened at a specific time
- **Source** — provenance: where a piece of data came from
- **Reflection** — an LLM-derived insight with source references
- **Chunk** — a text segment for embedding, traceable back to its source

### Behaviours (Pluggable Backends)

ExMemory defines Elixir behaviours for each subsystem. Backends implement callbacks.

| Behaviour | Purpose |
|-----------|---------|
| `Store` | CRUD + query for entities, facts, events, sources, reflections |
| `VectorIndex` | Embedding storage + similarity search |
| `Retriever` | Orchestrates store + vector queries (interface only in v0.1) |
| `Embedder` | Text → vector (interface only in v0.1) |
| `EventArchive` | Append-only event log (interface only in v0.1) |
| `Archive` | Snapshot / time-travel (interface only in v0.1) |

### Capabilities

Every backend exposes `capabilities/1` returning a `MapSet` of atoms. The system adapts behavior based on what's available.

| Capability | Description |
|-----------|-------------|
| `:transactions` | Atomic multi-operation transactions |
| `:vector_search` | Vector similarity queries |
| `:metadata_filtering` | Query by metadata fields |
| `:temporal_queries` | Time-range and validity-period queries |
| `:ann_index` | Approximate nearest neighbor indexing |
| `:reranking` | Secondary reranking of results |
| `:append_only` | Optimized for append-only workloads |
| `:snapshots` | Point-in-time snapshots |

### Query Struct

Queries are structs, not keyword arguments. Every backend receives the same input shape.

```elixir
%ExMemory.Query{
  vector: [0.9, 0.1, 0.0],
  top_k: 5,
  threshold: 0.8,
  filters: %{entity_id: "e1"},
  rerank: false
}
```

## Installation

Add `ex_memory` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_memory, "~> 0.1.0"}
  ]
end
```

Requires Elixir ~> 1.18.

## Quick Start

```elixir
alias ExMemory.{Store.SQLite, VectorIndex.SQLite, Entity, Fact, Event, Query}

# Initialize backends (in-memory for development)
{:ok, store} = SQLite.init(path: ":memory:")
{:ok, vidx} = SQLite.init(path: ":memory:")

# --- Episodic Memory ---

{:ok, event} = SQLite.insert(store, %Event{
  id: "ev1",
  event_type: "login",
  occurred_at: "2024-03-01T08:00:00Z",
  payload: %{"ip" => "10.0.0.1"}
})

{:ok, [^event]} = SQLite.query(store, :event, event_type: "login")

# --- Semantic Memory ---

{:ok, entity} = SQLite.insert(store, %Entity{id: "e1", type: "person", name: "Alice"})

{:ok, fact} = SQLite.insert(store, %Fact{
  id: "f1",
  subject: "Alice",
  predicate: "reports_to",
  object: "Bob",
  valid_from: "2024-01-01T00:00:00Z",
  valid_to: "2024-12-31T23:59:59Z"
})

# Query facts by subject
{:ok, facts} = SQLite.query(store, :fact, subject: "Alice")

# Query facts by temporal range
{:ok, current} = SQLite.query(store, :fact, [
  {:temporal, "valid_from", "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z"}
])

# --- Vector Search ---

{:ok, _} = SQLite.insert(vidx, %{
  id: "emb1",
  entity_id: "e1",
  vector: [1.0, 0.0, 0.0],
  dimension: 3,
  metadata: %{"category" => "profile"}
})

{:ok, results} = SQLite.query(vidx, %Query{
  vector: [0.9, 0.1, 0.0],
  top_k: 5,
  threshold: 0.8
})

# results => [%ExMemory.Result{id: "emb1", score: 0.995, data: %{entity_id: "e1", ...}}]

# --- Filter by metadata ---

{:ok, filtered} = SQLite.query(vidx, %Query{
  vector: [0.9, 0.1, 0.0],
  top_k: 5,
  filters: %{category: "profile"}
})

# --- Transactions ---

{:ok, :committed} = SQLite.transaction(store, fn s ->
  {:ok, _} = SQLite.insert(s, %Entity{id: "e2", type: "person", name: "Bob"})
  {:ok, _} = SQLite.insert(s, %Fact{id: "f2", subject: "Bob", predicate: "works_at", object: "Acme"})
  :committed
end)

# --- Capability Introspection ---

store_caps = SQLite.capabilities(store)
# => MapSet.new([:transactions, :metadata_filtering, :temporal_queries])

vidx_caps = SQLite.capabilities(vidx)
# => MapSet.new([:vector_search, :metadata_filtering, :transactions])

ExMemory.Capabilities.has?(store_caps, :temporal_queries)  # => true
ExMemory.Capabilities.has?(store_caps, :vector_search)     # => false
```

## Capability Matrix (v0.1.0)

| Capability | Store.SQLite | VectorIndex.SQLite |
|-----------|:---:|:---:|
| `:transactions` | ✓ | ✓ |
| `:vector_search` | | ✓ |
| `:metadata_filtering` | ✓ | ✓ |
| `:temporal_queries` | ✓ | |
| `:ann_index` | | |
| `:reranking` | | |
| `:append_only` | | |
| `:snapshots` | | |

## Architecture

```
┌──────────────────────────────────────┐
│  Application (Phoenix, CLI, Agent)   │
├──────────────────────────────────────┤
│           ExMemory API               │
│  ┌─────────┐ ┌─────────┐ ┌────────┐ │
│  │ Store   │ │ Vector  │ │Retrieve│ │
│  │ (behav) │ │ Index   │ │ (behav)│ │
│  └────┬────┘ └────┬────┘ └───┬────┘ │
│       │           │          │       │
│  ┌────┴────┐ ┌────┴────┐    │       │
│  │SQLite   │ │SQLite   │    │       │
│  │Store    │ │VecIdx   │    │       │
│  └─────────┘ └─────────┘    │       │
│  ┌──────────────────────────┘       │
│  │ Capabilities                      │
│  └───────────────────────────────────┘
├──────────────────────────────────────┤
│  SQLite (via exqlite NIF)           │
└──────────────────────────────────────┘
```

## File Structure

```
lib/ex_memory.ex                        # Public API facade
lib/ex_memory/
  entity.ex, fact.ex, event.ex          # Domain models
  source.ex, reflection.ex, chunk.ex    # Domain models
  store.ex, vector_index.ex             # Behaviours
  retriever.ex, embedder.ex             # Behaviours (interface only)
  event_archive.ex, archive.ex          # Behaviours (interface only)
  query.ex, result.ex, capabilities.ex  # Shared types
  store/sqlite.ex                       # Store.SQLite implementation
  vector_index/sqlite.ex                # VectorIndex.SQLite implementation
```

## SQLite Schema

### Store Tables

**entities** — `id, type, name, metadata (JSON), source_id, inserted_at, updated_at`
**facts** — `id, subject, predicate, object, valid_from, valid_to, observed_at, metadata (JSON), source_id, inserted_at, updated_at`
**events** — `id, event_type, payload (JSON), occurred_at, source_id, metadata (JSON), inserted_at` *(no updated_at — append-only)*
**sources** — `id, kind, identifier, metadata (JSON), inserted_at, updated_at`
**reflections** — `id, content, source_ids (JSON array), metadata (JSON), inserted_at, updated_at`

### Vector Table

**embeddings** — `id, entity_id, source_id, vector (BLOB float32), dimension, metadata (JSON), inserted_at, updated_at`

## Limitations (v0.1.0)

- Vector search is brute-force O(n) — no ANN indexing
- Single connection per backend instance — no connection pooling
- No migration system — schema created on init, no ALTER support
- No Embedder, Retriever, EventArchive, or Archive implementations yet
- Events are technically deletable via `delete/3` (update is blocked)

## What's Next

Potential directions for future phases:

- **mneme integration** — ANN vector search via VectorIndex behaviour
- **Ecto backend** — PostgreSQL Store for multi-process deployments
- **MCP interface** — Expose as an MCP tool for agent systems
- **Retriever orchestration** — Coordinate Store + VectorIndex queries
- **Embedder implementation** — HTTP-based text→vector (OpenAI, etc.)

## Documentation

Full API documentation is available at [HexDocs](https://hexdocs.pm/ex_memory).

## License

MIT. See [LICENSE](LICENSE).
