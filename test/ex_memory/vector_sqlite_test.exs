defmodule ExMemory.VectorSQLiteTest do
  use ExUnit.Case, async: true

  alias ExMemory.{Capabilities, Query, VectorIndex.SQLite}

  setup do
    {:ok, idx} = SQLite.init(path: ":memory:")
    %{idx: idx}
  end

  describe "vector insert and search" do
    test "inserts an embedding and retrieves it via search", %{idx: idx} do
      {:ok, _} =
        SQLite.insert(idx, %{
          id: "emb1",
          entity_id: "e1",
          vector: [1.0, 0.0, 0.0],
          dimension: 3,
          metadata: %{"label" => "x-axis"}
        })

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [1.0, 0.0, 0.0], top_k: 5})

      assert length(results) == 1
      [r] = results
      assert r.id == "emb1"
      assert_in_delta r.score, 1.0, 0.001
      assert r.data.entity_id == "e1"
    end

    test "finds the most similar vector among multiple", %{idx: idx} do
      SQLite.insert(idx, %{id: "a", vector: [1.0, 0.0, 0.0], dimension: 3})
      SQLite.insert(idx, %{id: "b", vector: [0.0, 1.0, 0.0], dimension: 3})
      SQLite.insert(idx, %{id: "c", vector: [0.0, 0.0, 1.0], dimension: 3})

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [0.9, 0.1, 0.0], top_k: 2})

      assert length(results) == 2
      assert hd(results).id == "a"
    end

    test "respects top_k limit", %{idx: idx} do
      for i <- 1..10 do
        SQLite.insert(idx, %{id: "v#{i}", vector: [1.0 / i, 0.0, 0.0], dimension: 3})
      end

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [1.0, 0.0, 0.0], top_k: 3})

      assert length(results) == 3
    end
  end

  describe "metadata filtering correctness" do
    test "filters by entity_id", %{idx: idx} do
      SQLite.insert(idx, %{id: "m1", entity_id: "ent1", vector: [1.0, 0.0], dimension: 2})
      SQLite.insert(idx, %{id: "m2", entity_id: "ent2", vector: [0.9, 0.1], dimension: 2})

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [1.0, 0.0], top_k: 10, filters: %{entity_id: "ent1"}})

      assert length(results) == 1
      assert hd(results).id == "m1"
    end

    test "filters by source_id", %{idx: idx} do
      SQLite.insert(idx, %{id: "m3", source_id: "src1", vector: [1.0, 0.0], dimension: 2})
      SQLite.insert(idx, %{id: "m4", source_id: "src2", vector: [0.8, 0.2], dimension: 2})

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [1.0, 0.0], top_k: 10, filters: %{source_id: "src2"}})

      assert length(results) == 1
      assert hd(results).id == "m4"
    end

    test "filters by arbitrary metadata key", %{idx: idx} do
      SQLite.insert(idx, %{
        id: "m5",
        vector: [1.0, 0.0],
        dimension: 2,
        metadata: %{"category" => "tech"}
      })

      SQLite.insert(idx, %{
        id: "m6",
        vector: [0.9, 0.1],
        dimension: 2,
        metadata: %{"category" => "sports"}
      })

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [1.0, 0.0], top_k: 10, filters: %{category: "tech"}})

      assert length(results) == 1
      assert hd(results).id == "m5"
    end
  end

  describe "top-k correctness" do
    test "returns exactly top_k results ordered by similarity", %{idx: idx} do
      vectors = [
        {"v1", [1.0, 0.0, 0.0]},
        {"v2", [0.8, 0.2, 0.0]},
        {"v3", [0.5, 0.5, 0.0]},
        {"v4", [0.0, 1.0, 0.0]},
        {"v5", [0.0, 0.0, 1.0]}
      ]

      for {id, vec} <- vectors do
        SQLite.insert(idx, %{id: id, vector: vec, dimension: 3})
      end

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [1.0, 0.0, 0.0], top_k: 3})

      assert length(results) == 3
      scores = Enum.map(results, & &1.score)
      assert scores == Enum.sort(scores, :desc)
    end
  end

  describe "threshold filtering" do
    test "excludes results below threshold", %{idx: idx} do
      SQLite.insert(idx, %{id: "t1", vector: [1.0, 0.0, 0.0], dimension: 3})
      SQLite.insert(idx, %{id: "t2", vector: [0.0, 1.0, 0.0], dimension: 3})

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [1.0, 0.0, 0.0], top_k: 10, threshold: 0.9})

      assert length(results) == 1
      assert hd(results).id == "t1"
    end
  end

  describe "delete" do
    test "deletes an embedding", %{idx: idx} do
      SQLite.insert(idx, %{id: "d1", vector: [1.0, 0.0], dimension: 2})
      {:ok, :deleted} = SQLite.delete(idx, "d1")

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [1.0, 0.0], top_k: 10})

      assert results == []
    end
  end

  describe "capability detection" do
    test "reports correct capabilities", %{idx: idx} do
      caps = SQLite.capabilities(idx)
      assert Capabilities.has?(caps, :vector_search)
      assert Capabilities.has?(caps, :metadata_filtering)
      assert Capabilities.has?(caps, :transactions)
      refute Capabilities.has?(caps, :ann_index)
      refute Capabilities.has?(caps, :reranking)
    end
  end

  describe "cosine similarity edge cases" do
    test "returns 0.0 for zero vectors", %{idx: idx} do
      SQLite.insert(idx, %{id: "z1", vector: [0.0, 0.0, 0.0], dimension: 3})

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [1.0, 0.0, 0.0], top_k: 5, threshold: 0.0})

      [r] = results
      assert_in_delta r.score, 0.0, 0.001
    end

    test "returns 1.0 for identical vectors", %{idx: idx} do
      SQLite.insert(idx, %{id: "same", vector: [0.577, 0.577, 0.577], dimension: 3})

      {:ok, results} =
        SQLite.query(idx, %Query{vector: [0.577, 0.577, 0.577], top_k: 5})

      [r] = results
      assert_in_delta r.score, 1.0, 0.01
    end
  end
end
