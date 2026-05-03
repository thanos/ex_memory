defmodule ExMemory.Store.SQLite do
  @moduledoc """
  SQLite-backed implementation of `ExMemory.Store`.

  Stores all domain objects (entities, facts, events, sources, reflections)
  in a single SQLite database file. Uses `exqlite` for direct NIF access.

  ## Usage

      {:ok, store} = ExMemory.Store.SQLite.init(path: "memory.db")
      {:ok, entity} = ExMemory.Store.SQLite.insert(store, %ExMemory.Entity{id: "1", type: "person", name: "Alice"})
      {:ok, [^entity]} = ExMemory.Store.SQLite.query(store, :entity, id: "1")
  """

  @behaviour ExMemory.Store

  alias ExMemory.{Entity, Fact, Event, Source, Reflection}

  @create_entities_sql """
  CREATE TABLE IF NOT EXISTS entities (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    name TEXT,
    metadata TEXT NOT NULL DEFAULT '{}',
    source_id TEXT,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """

  @create_facts_sql """
  CREATE TABLE IF NOT EXISTS facts (
    id TEXT PRIMARY KEY,
    subject TEXT NOT NULL,
    predicate TEXT NOT NULL,
    object TEXT NOT NULL,
    valid_from TEXT,
    valid_to TEXT,
    observed_at TEXT,
    metadata TEXT NOT NULL DEFAULT '{}',
    source_id TEXT,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """

  @create_events_sql """
  CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL DEFAULT '{}',
    occurred_at TEXT NOT NULL,
    source_id TEXT,
    metadata TEXT NOT NULL DEFAULT '{}',
    inserted_at TEXT NOT NULL
  )
  """

  @create_sources_sql """
  CREATE TABLE IF NOT EXISTS sources (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    identifier TEXT NOT NULL,
    metadata TEXT NOT NULL DEFAULT '{}',
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """

  @create_reflections_sql """
  CREATE TABLE IF NOT EXISTS reflections (
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    source_ids TEXT NOT NULL DEFAULT '[]',
    metadata TEXT NOT NULL DEFAULT '{}',
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """

  @impl true
  def init(opts) do
    path = Keyword.get(opts, :path, ":memory:")
    {:ok, conn} = Exqlite.Sqlite3.open(path)
    Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode=WAL")
    Exqlite.Sqlite3.execute(conn, "PRAGMA foreign_keys=ON")

    for sql <- [
          @create_entities_sql,
          @create_facts_sql,
          @create_events_sql,
          @create_sources_sql,
          @create_reflections_sql
        ] do
      Exqlite.Sqlite3.execute(conn, sql)
    end

    {:ok, %{conn: conn, path: path}}
  end

  @impl true
  def insert(%{conn: conn} = _state, %Entity{} = entity) do
    now = utc_now()
    entity = %{entity | inserted_at: now, updated_at: now}

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO entities (id, type, name, metadata, source_id, inserted_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        entity.id,
        entity.type,
        entity.name,
        Jason.encode!(entity.metadata),
        entity.source_id,
        entity.inserted_at,
        entity.updated_at
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, entity}
  end

  def insert(%{conn: conn} = _state, %Fact{} = fact) do
    now = utc_now()
    fact = %{fact | inserted_at: now, updated_at: now}

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO facts (id, subject, predicate, object, valid_from, valid_to, observed_at, metadata, source_id, inserted_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        fact.id,
        fact.subject,
        fact.predicate,
        fact.object,
        fact.valid_from,
        fact.valid_to,
        fact.observed_at,
        Jason.encode!(fact.metadata),
        fact.source_id,
        fact.inserted_at,
        fact.updated_at
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, fact}
  end

  def insert(%{conn: conn} = _state, %Event{} = event) do
    now = utc_now()
    event = %{event | inserted_at: now}

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO events (id, event_type, payload, occurred_at, source_id, metadata, inserted_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        event.id,
        event.event_type,
        Jason.encode!(event.payload),
        event.occurred_at,
        event.source_id,
        Jason.encode!(event.metadata),
        event.inserted_at
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, event}
  end

  def insert(%{conn: conn} = _state, %Source{} = source) do
    now = utc_now()
    source = %{source | inserted_at: now, updated_at: now}

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO sources (id, kind, identifier, metadata, inserted_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        source.id,
        source.kind,
        source.identifier,
        Jason.encode!(source.metadata),
        source.inserted_at,
        source.updated_at
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, source}
  end

  def insert(%{conn: conn} = _state, %Reflection{} = reflection) do
    now = utc_now()
    reflection = %{reflection | inserted_at: now, updated_at: now}

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO reflections (id, content, source_ids, metadata, inserted_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        reflection.id,
        reflection.content,
        Jason.encode!(reflection.source_ids),
        Jason.encode!(reflection.metadata),
        reflection.inserted_at,
        reflection.updated_at
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, reflection}
  end

  @impl true
  def update(%{conn: conn} = _state, %Entity{} = entity) do
    now = utc_now()
    entity = %{entity | updated_at: now}

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "UPDATE entities SET type = ?, name = ?, metadata = ?, source_id = ?, updated_at = ? WHERE id = ?"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        entity.type,
        entity.name,
        Jason.encode!(entity.metadata),
        entity.source_id,
        entity.updated_at,
        entity.id
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, entity}
  end

  def update(%{conn: conn} = _state, %Fact{} = fact) do
    now = utc_now()
    fact = %{fact | updated_at: now}

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "UPDATE facts SET subject = ?, predicate = ?, object = ?, valid_from = ?, valid_to = ?, observed_at = ?, metadata = ?, source_id = ?, updated_at = ? WHERE id = ?"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        fact.subject,
        fact.predicate,
        fact.object,
        fact.valid_from,
        fact.valid_to,
        fact.observed_at,
        Jason.encode!(fact.metadata),
        fact.source_id,
        fact.updated_at,
        fact.id
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, fact}
  end

  def update(%{conn: conn} = _state, %Source{} = source) do
    now = utc_now()
    source = %{source | updated_at: now}

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "UPDATE sources SET kind = ?, identifier = ?, metadata = ?, updated_at = ? WHERE id = ?"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        source.kind,
        source.identifier,
        Jason.encode!(source.metadata),
        source.updated_at,
        source.id
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, source}
  end

  def update(%{conn: conn} = _state, %Reflection{} = reflection) do
    now = utc_now()
    reflection = %{reflection | updated_at: now}

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "UPDATE reflections SET content = ?, source_ids = ?, metadata = ?, updated_at = ? WHERE id = ?"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        reflection.content,
        Jason.encode!(reflection.source_ids),
        Jason.encode!(reflection.metadata),
        reflection.updated_at,
        reflection.id
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, reflection}
  end

  def update(_state, %Event{}) do
    {:error, :events_are_append_only}
  end

  @impl true
  def query(%{conn: conn} = _state, :entity, filters) do
    {where, params} = build_where(filters)

    sql =
      case where do
        "" -> "SELECT * FROM entities"
        _ -> "SELECT * FROM entities WHERE #{where}"
      end

    rows = execute_query(conn, sql, params)
    {:ok, Enum.map(rows, &row_to_entity/1)}
  end

  def query(%{conn: conn} = _state, :fact, filters) do
    {where, params} = build_where(filters)

    sql =
      case where do
        "" -> "SELECT * FROM facts"
        _ -> "SELECT * FROM facts WHERE #{where}"
      end

    rows = execute_query(conn, sql, params)
    {:ok, Enum.map(rows, &row_to_fact/1)}
  end

  def query(%{conn: conn} = _state, :event, filters) do
    {where, params} = build_where(filters)

    sql =
      case where do
        "" -> "SELECT * FROM events"
        _ -> "SELECT * FROM events WHERE #{where}"
      end

    rows = execute_query(conn, sql, params)
    {:ok, Enum.map(rows, &row_to_event/1)}
  end

  def query(%{conn: conn} = _state, :source, filters) do
    {where, params} = build_where(filters)

    sql =
      case where do
        "" -> "SELECT * FROM sources"
        _ -> "SELECT * FROM sources WHERE #{where}"
      end

    rows = execute_query(conn, sql, params)
    {:ok, Enum.map(rows, &row_to_source/1)}
  end

  def query(%{conn: conn} = _state, :reflection, filters) do
    {where, params} = build_where(filters)

    sql =
      case where do
        "" -> "SELECT * FROM reflections"
        _ -> "SELECT * FROM reflections WHERE #{where}"
      end

    rows = execute_query(conn, sql, params)
    {:ok, Enum.map(rows, &row_to_reflection/1)}
  end

  @impl true
  def delete(%{conn: conn} = _state, :entity, id) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "DELETE FROM entities WHERE id = ?")
    :ok = Exqlite.Sqlite3.bind(stmt, [id])
    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, :deleted}
  end

  def delete(%{conn: conn} = _state, :fact, id) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "DELETE FROM facts WHERE id = ?")
    :ok = Exqlite.Sqlite3.bind(stmt, [id])
    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, :deleted}
  end

  def delete(%{conn: conn} = _state, :event, id) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "DELETE FROM events WHERE id = ?")
    :ok = Exqlite.Sqlite3.bind(stmt, [id])
    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, :deleted}
  end

  def delete(%{conn: conn} = _state, :source, id) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "DELETE FROM sources WHERE id = ?")
    :ok = Exqlite.Sqlite3.bind(stmt, [id])
    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, :deleted}
  end

  def delete(%{conn: conn} = _state, :reflection, id) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "DELETE FROM reflections WHERE id = ?")
    :ok = Exqlite.Sqlite3.bind(stmt, [id])
    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, :deleted}
  end

  @impl true
  def transaction(%{conn: conn} = state, fun) do
    Exqlite.Sqlite3.execute(conn, "BEGIN")

    try do
      result = fun.(state)
      Exqlite.Sqlite3.execute(conn, "COMMIT")
      {:ok, result}
    rescue
      e ->
        Exqlite.Sqlite3.execute(conn, "ROLLBACK")
        {:error, e}
    end
  end

  @impl true
  def capabilities(_state) do
    MapSet.new([:transactions, :metadata_filtering, :temporal_queries])
  end

  defp execute_query(conn, sql, params) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, sql)
    :ok = Exqlite.Sqlite3.bind(stmt, params)

    result =
      case Exqlite.Sqlite3.fetch_all(conn, stmt) do
        {:ok, rows} -> rows
        {:error, _} -> []
      end

    Exqlite.Sqlite3.release(conn, stmt)
    result
  end

  defp build_where(filters) do
    filters
    |> Enum.reduce({"", []}, fn
      {:id, v}, {w, p} ->
        {append_and(w, "id = ?"), p ++ [v]}

      {:type, v}, {w, p} ->
        {append_and(w, "type = ?"), p ++ [v]}

      {:name, v}, {w, p} ->
        {append_and(w, "name = ?"), p ++ [v]}

      {:subject, v}, {w, p} ->
        {append_and(w, "subject = ?"), p ++ [v]}

      {:predicate, v}, {w, p} ->
        {append_and(w, "predicate = ?"), p ++ [v]}

      {:object, v}, {w, p} ->
        {append_and(w, "object = ?"), p ++ [v]}

      {:event_type, v}, {w, p} ->
        {append_and(w, "event_type = ?"), p ++ [v]}

      {:kind, v}, {w, p} ->
        {append_and(w, "kind = ?"), p ++ [v]}

      {:identifier, v}, {w, p} ->
        {append_and(w, "identifier = ?"), p ++ [v]}

      {:source_id, v}, {w, p} ->
        {append_and(w, "source_id = ?"), p ++ [v]}

      {:content, v}, {w, p} ->
        {append_and(w, "content = ?"), p ++ [v]}

      {:metadata, key, v}, {w, p} ->
        {append_and(w, "json_extract(metadata, '$.#{key}') = ?"), p ++ [v]}

      {:temporal, field, from, to}, {w, p} ->
        {append_and(w, "#{field} >= ? AND #{field} <= ?"), p ++ [from, to]}

      _, acc ->
        acc
    end)
  end

  defp append_and("", clause), do: clause
  defp append_and(where, clause), do: "#{where} AND #{clause}"

  defp row_to_entity([id, type, name, metadata_json, source_id, inserted_at, updated_at]) do
    %Entity{
      id: id,
      type: type,
      name: name,
      metadata: Jason.decode!(metadata_json),
      source_id: source_id,
      inserted_at: inserted_at,
      updated_at: updated_at
    }
  end

  defp row_to_fact([
         id,
         subject,
         predicate,
         object,
         valid_from,
         valid_to,
         observed_at,
         metadata_json,
         source_id,
         inserted_at,
         updated_at
       ]) do
    %Fact{
      id: id,
      subject: subject,
      predicate: predicate,
      object: object,
      valid_from: valid_from,
      valid_to: valid_to,
      observed_at: observed_at,
      metadata: Jason.decode!(metadata_json),
      source_id: source_id,
      inserted_at: inserted_at,
      updated_at: updated_at
    }
  end

  defp row_to_event([
         id,
         event_type,
         payload_json,
         occurred_at,
         source_id,
         metadata_json,
         inserted_at
       ]) do
    %Event{
      id: id,
      event_type: event_type,
      payload: Jason.decode!(payload_json),
      occurred_at: occurred_at,
      source_id: source_id,
      metadata: Jason.decode!(metadata_json),
      inserted_at: inserted_at
    }
  end

  defp row_to_source([id, kind, identifier, metadata_json, inserted_at, updated_at]) do
    %Source{
      id: id,
      kind: kind,
      identifier: identifier,
      metadata: Jason.decode!(metadata_json),
      inserted_at: inserted_at,
      updated_at: updated_at
    }
  end

  defp row_to_reflection([id, content, source_ids_json, metadata_json, inserted_at, updated_at]) do
    %Reflection{
      id: id,
      content: content,
      source_ids: Jason.decode!(source_ids_json),
      metadata: Jason.decode!(metadata_json),
      inserted_at: inserted_at,
      updated_at: updated_at
    }
  end

  defp utc_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
