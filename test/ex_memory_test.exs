defmodule ExMemoryTest do
  use ExUnit.Case, async: true

  alias ExMemory.{Capabilities, Chunk, Entity, Event, Fact, Query, Reflection, Result, Source}

  describe "domain models" do
    test "Entity struct has required fields" do
      e = %Entity{id: "1", type: "person"}
      assert e.id == "1"
      assert e.type == "person"
      assert e.metadata == %{}
    end

    test "Fact struct has SPO and temporal fields" do
      f = %Fact{id: "1", subject: "A", predicate: "knows", object: "B"}
      assert f.subject == "A"
      assert f.valid_from == nil
      assert f.valid_to == nil
    end

    test "Event struct is append-only" do
      e = %Event{id: "1", event_type: "click", occurred_at: "2024-01-01"}
      assert e.inserted_at == nil
    end

    test "Source struct records provenance" do
      s = %Source{id: "1", kind: "api", identifier: "web"}
      assert s.kind == "api"
    end

    test "Reflection struct carries source_ids" do
      r = %Reflection{id: "1", content: "insight"}
      assert r.source_ids == []
    end

    test "Chunk struct is unit of vectorization" do
      c = %Chunk{id: "1", content: "hello world"}
      assert c.source_id == nil
    end
  end

  describe "Query struct" do
    test "has sensible defaults" do
      q = %Query{}
      assert q.top_k == 10
      assert q.threshold == nil
      assert q.filters == %{}
      assert q.rerank == false
    end
  end

  describe "Result struct" do
    test "carries id, score, data" do
      r = %Result{id: "1", score: 0.95}
      assert r.data == %{}
      assert r.metadata == %{}
    end
  end

  describe "Capabilities" do
    test "all/0 returns the full capability list" do
      all = Capabilities.all()
      assert :transactions in all
      assert :vector_search in all
      assert length(all) == 8
    end

    test "has?/2 checks membership" do
      caps = MapSet.new([:transactions, :metadata_filtering])
      assert Capabilities.has?(caps, :transactions)
      refute Capabilities.has?(caps, :vector_search)
    end

    test "check!/2 raises on missing capability" do
      caps = MapSet.new([:transactions])
      assert :ok == Capabilities.check!(caps, :transactions)

      assert_raise RuntimeError, fn ->
        Capabilities.check!(caps, :vector_search)
      end
    end
  end
end
