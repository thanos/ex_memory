# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-03

### Added

- Core domain models: `Entity`, `Fact`, `Event`, `Source`, `Reflection`, `Chunk`
- Behaviour definitions: `Store`, `VectorIndex`, `Retriever`, `Embedder`, `EventArchive`, `Archive`
- `Store.SQLite` — full CRUD for entities, facts, events, sources, reflections with SQLite backend
- `VectorIndex.SQLite` — brute-force cosine similarity search with metadata pre-filtering
- `Query` struct — unified query abstraction for vector + metadata + temporal queries
- `Result` struct — search result carrying id, score, data, and metadata
- `Capabilities` system — runtime introspection of backend abilities (`capabilities/1` returning `MapSet`)
- Transaction support in `Store.SQLite` (BEGIN/COMMIT/ROLLBACK)
- Temporal query support for facts (`valid_from`/`valid_to` range queries)
- Metadata filtering via `json_extract` for both Store and VectorIndex
- Events are append-only — `update/2` returns `{:error, :events_are_append_only}`
- Vectors stored as BLOB (float32 native endian) for efficient storage and retrieval
- Dependencies: `exqlite ~> 0.19` (NIF SQLite driver), `jason ~> 1.4` (JSON)
- 43 tests covering all Store operations, VectorIndex search, capabilities, and edge cases
- Educational documentation: memory systems, vector dimensions, storage design, code walkthrough
- Design documentation: architecture, storage, vector, capabilities

[0.1.0]: https://github.com/thanos/ex_memory/releases/tag/v0.1.0
