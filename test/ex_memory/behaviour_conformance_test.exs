defmodule ExMemory.BehaviourConformanceTest do
  use ExUnit.Case, async: true

  import Mox

  alias ExMemory.{
    StoreMock,
    VectorIndexMock,
    RetrieverMock,
    EmbedderMock,
    EventArchiveMock,
    ArchiveMock,
    Entity,
    Fact,
    Event,
    Query
  }

  setup :verify_on_exit!

  describe "Store behaviour conformance" do
    test "init/1 callback" do
      StoreMock |> expect(:init, fn opts -> {:ok, %{opts: opts}} end)
      assert {:ok, %{opts: [path: "test.db"]}} == StoreMock.init(path: "test.db")
    end

    test "insert/2 callback with entity" do
      entity = %Entity{id: "e1", type: "person", name: "Alice"}
      state = %{conn: :fake}

      StoreMock
      |> expect(:insert, fn ^state, ^entity -> {:ok, entity} end)

      assert {:ok, ^entity} = StoreMock.insert(state, entity)
    end

    test "insert/2 callback with fact" do
      fact = %Fact{id: "f1", subject: "A", predicate: "knows", object: "B"}
      state = %{conn: :fake}

      StoreMock
      |> expect(:insert, fn ^state, ^fact -> {:ok, fact} end)

      assert {:ok, ^fact} = StoreMock.insert(state, fact)
    end

    test "insert/2 callback with event" do
      event = %Event{id: "ev1", event_type: "login", occurred_at: "2024-01-01"}
      state = %{conn: :fake}

      StoreMock
      |> expect(:insert, fn ^state, ^event -> {:ok, event} end)

      assert {:ok, ^event} = StoreMock.insert(state, event)
    end

    test "update/2 callback" do
      entity = %Entity{id: "e1", type: "person", name: "Alice Updated"}
      state = %{conn: :fake}

      StoreMock
      |> expect(:update, fn ^state, ^entity -> {:ok, entity} end)

      assert {:ok, ^entity} = StoreMock.update(state, entity)
    end

    test "query/3 callback" do
      state = %{conn: :fake}

      StoreMock
      |> expect(:query, fn ^state, :entity, id: "e1" ->
        {:ok, [%Entity{id: "e1", type: "person"}]}
      end)

      assert {:ok, [%Entity{id: "e1"}]} = StoreMock.query(state, :entity, id: "e1")
    end

    test "delete/3 callback" do
      state = %{conn: :fake}

      StoreMock
      |> expect(:delete, fn ^state, :entity, "e1" -> {:ok, :deleted} end)

      assert {:ok, :deleted} = StoreMock.delete(state, :entity, "e1")
    end

    test "transaction/2 callback" do
      state = %{conn: :fake}

      StoreMock
      |> expect(:transaction, fn ^state, _fun -> {:ok, :result} end)

      assert {:ok, :result} = StoreMock.transaction(state, fn _ -> :result end)
    end

    test "capabilities/1 callback" do
      state = %{conn: :fake}

      StoreMock
      |> expect(:capabilities, fn ^state -> MapSet.new([:transactions]) end)

      assert MapSet.new([:transactions]) == StoreMock.capabilities(state)
    end
  end

  describe "VectorIndex behaviour conformance" do
    test "init/1 callback" do
      VectorIndexMock |> expect(:init, fn opts -> {:ok, %{opts: opts}} end)
      assert {:ok, _} = VectorIndexMock.init(path: "test.db")
    end

    test "insert/2 callback" do
      embedding = %{id: "emb1", vector: [1.0, 0.0], dimension: 2}
      state = %{conn: :fake}

      VectorIndexMock
      |> expect(:insert, fn ^state, ^embedding -> {:ok, embedding} end)

      assert {:ok, ^embedding} = VectorIndexMock.insert(state, embedding)
    end

    test "query/2 callback" do
      query = %Query{vector: [1.0, 0.0], top_k: 5}
      state = %{conn: :fake}

      VectorIndexMock
      |> expect(:query, fn ^state, ^query -> {:ok, []} end)

      assert {:ok, []} = VectorIndexMock.query(state, query)
    end

    test "delete/2 callback" do
      state = %{conn: :fake}

      VectorIndexMock
      |> expect(:delete, fn ^state, "emb1" -> {:ok, :deleted} end)

      assert {:ok, :deleted} = VectorIndexMock.delete(state, "emb1")
    end

    test "capabilities/1 callback" do
      state = %{conn: :fake}

      VectorIndexMock
      |> expect(:capabilities, fn ^state -> MapSet.new([:vector_search]) end)

      assert MapSet.new([:vector_search]) == VectorIndexMock.capabilities(state)
    end
  end

  describe "Retriever behaviour conformance" do
    test "init/1 callback" do
      RetrieverMock |> expect(:init, fn opts -> {:ok, %{opts: opts}} end)
      assert {:ok, _} = RetrieverMock.init(store: :fake, vidx: :fake)
    end

    test "retrieve/2 callback" do
      query = %Query{vector: [1.0, 0.0], top_k: 5}
      state = %{conn: :fake}

      RetrieverMock
      |> expect(:retrieve, fn ^state, ^query -> {:ok, []} end)

      assert {:ok, []} = RetrieverMock.retrieve(state, query)
    end

    test "capabilities/1 callback" do
      state = %{conn: :fake}

      RetrieverMock
      |> expect(:capabilities, fn ^state -> MapSet.new([:reranking]) end)

      assert MapSet.new([:reranking]) == RetrieverMock.capabilities(state)
    end
  end

  describe "Embedder behaviour conformance" do
    test "init/1 callback" do
      EmbedderMock |> expect(:init, fn opts -> {:ok, %{opts: opts}} end)
      assert {:ok, _} = EmbedderMock.init(model: "text-embedding-3-small")
    end

    test "embed/2 callback" do
      state = %{model: "test"}

      EmbedderMock
      |> expect(:embed, fn ^state, "hello" -> {:ok, [1.0, 0.0, 0.0]} end)

      assert {:ok, [1.0, 0.0, 0.0]} = EmbedderMock.embed(state, "hello")
    end

    test "embed_batch/2 callback" do
      state = %{model: "test"}

      EmbedderMock
      |> expect(:embed_batch, fn ^state, ["a", "b"] -> {:ok, [[1.0], [0.0]]} end)

      assert {:ok, [[1.0], [0.0]]} = EmbedderMock.embed_batch(state, ["a", "b"])
    end

    test "dimensions/1 callback" do
      state = %{model: "test"}

      EmbedderMock
      |> expect(:dimensions, fn ^state -> 1536 end)

      assert 1536 == EmbedderMock.dimensions(state)
    end
  end

  describe "EventArchive behaviour conformance" do
    test "init/1 callback" do
      EventArchiveMock |> expect(:init, fn opts -> {:ok, %{opts: opts}} end)
      assert {:ok, _} = EventArchiveMock.init(path: "events.db")
    end

    test "append/2 callback" do
      event = %Event{id: "ev1", event_type: "click", occurred_at: "2024-01-01"}
      state = %{conn: :fake}

      EventArchiveMock
      |> expect(:append, fn ^state, ^event -> {:ok, event} end)

      assert {:ok, ^event} = EventArchiveMock.append(state, event)
    end

    test "query/2 callback" do
      state = %{conn: :fake}

      EventArchiveMock
      |> expect(:query, fn ^state, event_type: "click" -> {:ok, []} end)

      assert {:ok, []} = EventArchiveMock.query(state, event_type: "click")
    end

    test "capabilities/1 callback" do
      state = %{conn: :fake}

      EventArchiveMock
      |> expect(:capabilities, fn ^state -> MapSet.new([:append_only]) end)

      assert MapSet.new([:append_only]) == EventArchiveMock.capabilities(state)
    end
  end

  describe "Archive behaviour conformance" do
    test "init/1 callback" do
      ArchiveMock |> expect(:init, fn opts -> {:ok, %{opts: opts}} end)
      assert {:ok, _} = ArchiveMock.init(path: "archive.db")
    end

    test "snapshot/2 callback" do
      state = %{conn: :fake}

      ArchiveMock
      |> expect(:snapshot, fn ^state, "v1" -> {:ok, :snapshot_created} end)

      assert {:ok, :snapshot_created} = ArchiveMock.snapshot(state, "v1")
    end

    test "restore/2 callback" do
      state = %{conn: :fake}

      ArchiveMock
      |> expect(:restore, fn ^state, "v1" -> {:ok, :restored} end)

      assert {:ok, :restored} = ArchiveMock.restore(state, "v1")
    end

    test "list_snapshots/1 callback" do
      state = %{conn: :fake}

      ArchiveMock
      |> expect(:list_snapshots, fn ^state -> {:ok, [%{label: "v1"}]} end)

      assert {:ok, [%{label: "v1"}]} = ArchiveMock.list_snapshots(state)
    end

    test "capabilities/1 callback" do
      state = %{conn: :fake}

      ArchiveMock
      |> expect(:capabilities, fn ^state -> MapSet.new([:snapshots]) end)

      assert MapSet.new([:snapshots]) == ArchiveMock.capabilities(state)
    end
  end
end
