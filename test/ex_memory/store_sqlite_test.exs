defmodule ExMemory.StoreSQLiteTest do
  use ExUnit.Case, async: true

  alias ExMemory.{Capabilities, Entity, Event, Fact, Reflection, Source, Store.SQLite}

  setup do
    {:ok, store} = SQLite.init(path: ":memory:")
    %{store: store}
  end

  describe "entity insert and retrieval" do
    test "inserts and retrieves an entity", %{store: store} do
      entity = %Entity{id: "e1", type: "person", name: "Alice"}
      {:ok, inserted} = SQLite.insert(store, entity)

      assert inserted.id == "e1"
      assert inserted.type == "person"
      assert inserted.name == "Alice"
      assert inserted.inserted_at != nil
      assert inserted.updated_at != nil

      {:ok, [retrieved]} = SQLite.query(store, :entity, id: "e1")
      assert retrieved.id == "e1"
      assert retrieved.name == "Alice"
    end

    test "updates an entity", %{store: store} do
      {:ok, entity} = SQLite.insert(store, %Entity{id: "e2", type: "person", name: "Bob"})
      updated = %{entity | name: "Robert", metadata: %{"role" => "admin"}}
      {:ok, result} = SQLite.update(store, updated)

      assert result.name == "Robert"
      assert result.metadata == %{"role" => "admin"}
      assert result.updated_at != entity.updated_at

      {:ok, [retrieved]} = SQLite.query(store, :entity, id: "e2")
      assert retrieved.name == "Robert"
    end

    test "deletes an entity", %{store: store} do
      SQLite.insert(store, %Entity{id: "e3", type: "org", name: "Acme"})
      {:ok, :deleted} = SQLite.delete(store, :entity, "e3")
      {:ok, []} = SQLite.query(store, :entity, id: "e3")
    end

    test "queries entities by type", %{store: store} do
      SQLite.insert(store, %Entity{id: "e4", type: "person", name: "Carol"})
      SQLite.insert(store, %Entity{id: "e5", type: "org", name: "Beta"})
      {:ok, people} = SQLite.query(store, :entity, type: "person")
      assert length(people) == 1
      assert hd(people).name == "Carol"
    end

    test "queries entities by metadata", %{store: store} do
      entity = %Entity{id: "e6", type: "person", name: "Dave", metadata: %{"dept" => "eng"}}
      SQLite.insert(store, entity)
      {:ok, results} = SQLite.query(store, :entity, [{:metadata, "dept", "eng"}])
      assert length(results) == 1
      assert hd(results).name == "Dave"
    end
  end

  describe "fact insert and temporal query behavior" do
    test "inserts and retrieves a fact", %{store: store} do
      fact = %Fact{
        id: "f1",
        subject: "Alice",
        predicate: "reports_to",
        object: "Bob",
        valid_from: "2024-01-01T00:00:00Z",
        valid_to: "2024-12-31T23:59:59Z",
        observed_at: "2024-01-15T10:00:00Z"
      }

      {:ok, inserted} = SQLite.insert(store, fact)
      assert inserted.id == "f1"
      assert inserted.subject == "Alice"

      {:ok, [retrieved]} = SQLite.query(store, :fact, id: "f1")
      assert retrieved.subject == "Alice"
      assert retrieved.predicate == "reports_to"
      assert retrieved.object == "Bob"
      assert retrieved.valid_from == "2024-01-01T00:00:00Z"
    end

    test "queries facts by subject", %{store: store} do
      SQLite.insert(store, %Fact{
        id: "f2",
        subject: "Carol",
        predicate: "works_at",
        object: "Acme"
      })

      SQLite.insert(store, %Fact{id: "f3", subject: "Dave", predicate: "works_at", object: "Beta"})

      {:ok, results} = SQLite.query(store, :fact, subject: "Carol")
      assert length(results) == 1
      assert hd(results).object == "Acme"
    end

    test "queries facts by temporal range", %{store: store} do
      SQLite.insert(store, %Fact{
        id: "f4",
        subject: "Eve",
        predicate: "contract",
        object: "Gamma",
        valid_from: "2024-06-01T00:00:00Z",
        valid_to: "2024-09-30T23:59:59Z"
      })

      {:ok, results} =
        SQLite.query(store, :fact, [
          {:temporal, "valid_from", "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z"}
        ])

      assert length(results) == 1
      assert hd(results).subject == "Eve"
    end

    test "updates a fact", %{store: store} do
      {:ok, fact} =
        SQLite.insert(store, %Fact{id: "f5", subject: "A", predicate: "p", object: "B"})

      {:ok, updated} = SQLite.update(store, %{fact | object: "C"})
      assert updated.object == "C"
    end
  end

  describe "event append and retrieval" do
    test "inserts and retrieves an event", %{store: store} do
      event = %Event{
        id: "ev1",
        event_type: "login",
        occurred_at: "2024-03-01T08:00:00Z",
        payload: %{"ip" => "10.0.0.1"}
      }

      {:ok, inserted} = SQLite.insert(store, event)
      assert inserted.id == "ev1"
      assert inserted.payload == %{"ip" => "10.0.0.1"}

      {:ok, [retrieved]} = SQLite.query(store, :event, id: "ev1")
      assert retrieved.event_type == "login"
      assert retrieved.payload == %{"ip" => "10.0.0.1"}
    end

    test "events cannot be updated", %{store: store} do
      {:ok, event} =
        SQLite.insert(store, %Event{
          id: "ev2",
          event_type: "click",
          occurred_at: "2024-03-01T09:00:00Z"
        })

      assert {:error, :events_are_append_only} == SQLite.update(store, event)
    end

    test "queries events by type", %{store: store} do
      SQLite.insert(store, %Event{
        id: "ev3",
        event_type: "login",
        occurred_at: "2024-03-01T10:00:00Z"
      })

      SQLite.insert(store, %Event{
        id: "ev4",
        event_type: "logout",
        occurred_at: "2024-03-01T18:00:00Z"
      })

      {:ok, results} = SQLite.query(store, :event, event_type: "login")
      assert length(results) == 1
    end

    test "queries events by source_id", %{store: store} do
      source = %Source{id: "s1", kind: "api", identifier: "web-app"}
      {:ok, _} = SQLite.insert(store, source)

      SQLite.insert(store, %Event{
        id: "ev5",
        event_type: "api_call",
        occurred_at: "2024-03-01T11:00:00Z",
        source_id: "s1"
      })

      {:ok, results} = SQLite.query(store, :event, source_id: "s1")
      assert length(results) == 1
    end
  end

  describe "source operations" do
    test "inserts and retrieves a source", %{store: store} do
      source = %Source{id: "s2", kind: "import", identifier: "csv-upload"}
      {:ok, inserted} = SQLite.insert(store, source)
      assert inserted.kind == "import"

      {:ok, [retrieved]} = SQLite.query(store, :source, id: "s2")
      assert retrieved.identifier == "csv-upload"
    end

    test "updates a source", %{store: store} do
      {:ok, source} = SQLite.insert(store, %Source{id: "s3", kind: "api", identifier: "v1"})
      {:ok, updated} = SQLite.update(store, %{source | identifier: "v2"})
      assert updated.identifier == "v2"
    end
  end

  describe "reflection operations" do
    test "inserts and retrieves a reflection", %{store: store} do
      reflection = %Reflection{
        id: "r1",
        content: "User prefers concise answers",
        source_ids: ["s1", "s2"]
      }

      {:ok, inserted} = SQLite.insert(store, reflection)
      assert inserted.content == "User prefers concise answers"

      {:ok, [retrieved]} = SQLite.query(store, :reflection, id: "r1")
      assert retrieved.source_ids == ["s1", "s2"]
    end

    test "updates a reflection", %{store: store} do
      {:ok, reflection} = SQLite.insert(store, %Reflection{id: "r2", content: "Initial insight"})
      {:ok, updated} = SQLite.update(store, %{reflection | content: "Revised insight"})
      assert updated.content == "Revised insight"
    end
  end

  describe "transaction behavior" do
    test "commits a transaction successfully", %{store: store} do
      {:ok, result} =
        SQLite.transaction(store, fn s ->
          {:ok, _} = SQLite.insert(s, %Entity{id: "tx1", type: "test", name: "TX"})
          {:ok, _} = SQLite.insert(s, %Entity{id: "tx2", type: "test", name: "TX2"})
          :both_inserted
        end)

      assert result == :both_inserted
      {:ok, results} = SQLite.query(store, :entity, type: "test")
      assert length(results) == 2
    end

    test "rolls back a transaction on error", %{store: store} do
      SQLite.transaction(store, fn s ->
        {:ok, _} = SQLite.insert(s, %Entity{id: "tx3", type: "rollback", name: "WillRollback"})
        raise "force rollback"
      end)

      {:ok, results} = SQLite.query(store, :entity, type: "rollback")
      assert results == []
    end
  end

  describe "capability detection" do
    test "reports correct capabilities", %{store: store} do
      caps = SQLite.capabilities(store)
      assert Capabilities.has?(caps, :transactions)
      assert Capabilities.has?(caps, :metadata_filtering)
      assert Capabilities.has?(caps, :temporal_queries)
      refute Capabilities.has?(caps, :vector_search)
      refute Capabilities.has?(caps, :ann_index)
    end
  end
end
