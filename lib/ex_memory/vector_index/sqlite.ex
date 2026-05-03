defmodule ExMemory.VectorIndex.SQLite do
  @moduledoc """
  SQLite-backed implementation of `ExMemory.VectorIndex`.

  Stores embeddings as BLOBs (float32 arrays) and performs brute-force
  cosine similarity search with metadata pre-filtering.

  Phase 1 only: flat index, no ANN. Suitable for < 100K vectors.

  ## Usage

      {:ok, idx} = ExMemory.VectorIndex.SQLite.init(path: "memory.db")
      {:ok, emb} = ExMemory.VectorIndex.SQLite.insert(idx, %{
        id: "emb1", entity_id: "e1", vector: [1.0, 0.0, 0.0], dimension: 3
      })
      {:ok, results} = ExMemory.VectorIndex.SQLite.query(idx, %ExMemory.Query{
        vector: [0.9, 0.1, 0.0], top_k: 5
      })
  """

  @behaviour ExMemory.VectorIndex

  @create_embeddings_sql """
  CREATE TABLE IF NOT EXISTS embeddings (
    id TEXT PRIMARY KEY,
    entity_id TEXT,
    source_id TEXT,
    vector BLOB NOT NULL,
    dimension INTEGER NOT NULL,
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
    Exqlite.Sqlite3.execute(conn, @create_embeddings_sql)
    {:ok, %{conn: conn, path: path}}
  end

  @impl true
  def insert(%{conn: conn} = _state, %{id: id, vector: vector} = embedding) do
    now = utc_now()
    dimension = length(vector)
    blob = encode_vector(vector)
    entity_id = Map.get(embedding, :entity_id)
    source_id = Map.get(embedding, :source_id)
    metadata = Map.get(embedding, :metadata, %{})

    {:ok, stmt} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO embeddings (id, entity_id, source_id, vector, dimension, metadata, inserted_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
      )

    :ok =
      Exqlite.Sqlite3.bind(stmt, [
        id,
        entity_id,
        source_id,
        {:blob, blob},
        dimension,
        Jason.encode!(metadata),
        now,
        now
      ])

    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)

    {:ok,
     %{
       id: id,
       entity_id: entity_id,
       source_id: source_id,
       vector: vector,
       dimension: dimension,
       metadata: metadata,
       inserted_at: now,
       updated_at: now
     }}
  end

  @impl true
  def query(%{conn: conn} = _state, %ExMemory.Query{} = q) do
    {where, params} = build_where(q.filters)

    sql =
      case where do
        "" ->
          "SELECT id, entity_id, source_id, vector, metadata, inserted_at, updated_at FROM embeddings"

        _ ->
          "SELECT id, entity_id, source_id, vector, metadata, inserted_at, updated_at FROM embeddings WHERE #{where}"
      end

    rows = execute_query(conn, sql, params)
    query_vector = q.vector || []

    results =
      rows
      |> Enum.map(fn [id, entity_id, source_id, blob, metadata_json, inserted_at, updated_at] ->
        stored_vector = decode_vector(blob)
        score = cosine_similarity(query_vector, stored_vector)
        {id, entity_id, source_id, stored_vector, metadata_json, inserted_at, updated_at, score}
      end)
      |> Enum.filter(fn {_, _, _, _, _, _, _, score} ->
        case q.threshold do
          nil -> true
          t -> score >= t
        end
      end)
      |> Enum.sort_by(fn {_, _, _, _, _, _, _, score} -> -score end)
      |> Enum.take(q.top_k)
      |> Enum.map(fn {id, entity_id, source_id, stored_vector, metadata_json, inserted_at,
                      updated_at, score} ->
        %ExMemory.Result{
          id: id,
          score: score,
          data: %{
            entity_id: entity_id,
            source_id: source_id,
            vector: stored_vector,
            metadata: Jason.decode!(metadata_json),
            inserted_at: inserted_at,
            updated_at: updated_at
          }
        }
      end)

    {:ok, results}
  end

  @impl true
  def delete(%{conn: conn} = _state, id) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "DELETE FROM embeddings WHERE id = ?")
    :ok = Exqlite.Sqlite3.bind(stmt, [id])
    Exqlite.Sqlite3.step(conn, stmt)
    Exqlite.Sqlite3.release(conn, stmt)
    {:ok, :deleted}
  end

  @impl true
  def capabilities(_state) do
    MapSet.new([:vector_search, :metadata_filtering, :transactions])
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

  defp build_where(filters) when map_size(filters) == 0, do: {"", []}

  defp build_where(filters) do
    filters
    |> Enum.reduce({"", []}, fn
      {:entity_id, v}, {w, p} ->
        {append_and(w, "entity_id = ?"), p ++ [v]}

      {:source_id, v}, {w, p} ->
        {append_and(w, "source_id = ?"), p ++ [v]}

      {key, v}, {w, p} when is_atom(key) ->
        {append_and(w, "json_extract(metadata, '$.#{key}') = ?"), p ++ [v]}

      _, acc ->
        acc
    end)
  end

  defp append_and("", clause), do: clause
  defp append_and(where, clause), do: "#{where} AND #{clause}"

  defp encode_vector(vector) do
    Enum.reduce(vector, <<>>, fn f, acc -> acc <> <<f::float-32-native>> end)
  end

  defp decode_vector(blob) do
    decode_vector_acc(blob, [])
  end

  defp decode_vector_acc(<<>>, acc), do: Enum.reverse(acc)

  defp decode_vector_acc(<<f::float-32-native, rest::binary>>, acc),
    do: decode_vector_acc(rest, [f | acc])

  defp cosine_similarity([], _), do: 0.0
  defp cosine_similarity(_, []), do: 0.0

  defp cosine_similarity(a, b) when length(a) != length(b), do: 0.0

  defp cosine_similarity(a, b) do
    dot = Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    norm_a = :math.sqrt(Enum.reduce(a, 0.0, fn x, acc -> acc + x * x end))
    norm_b = :math.sqrt(Enum.reduce(b, 0.0, fn x, acc -> acc + x * x end))

    if norm_a == 0.0 or norm_b == 0.0 do
      0.0
    else
      dot / (norm_a * norm_b)
    end
  end

  defp utc_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
