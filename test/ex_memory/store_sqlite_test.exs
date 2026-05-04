defmodule ExMemory.StoreSQLiteTest do
  use ExUnit.Case, async: true

  alias ExMemory.{Capabilities, Entity, Event, Fact, Reflection, Source, Store.SQLite}

  setup do
    {:ok, store} = SQLite.init(path: ":memory:")
    %{store: store}
  end

  describe "init/1" do
    test "initializes with default :memory path" do
      {:ok, store} = SQLite.init([])
      assert %{conn: _, path: ":memory:"} = store
    end

    test "initializes with custom path" do
      path =
        System.tmp_dir!() |> Path.join("ex_memory_test_#{:erlang.unique_integer([:positive])}.db")

      {:ok, store} = SQLite.init(path: path)
      assert %{conn: _, path: ^path} = store
      File.rm(path)
    end
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

    test "inserts entity with source_id and metadata", %{store: store} do
      entity = %Entity{
        id: "e_meta",
        type: "person",
        name: "Zara",
        source_id: "s1",
        metadata: %{"level" => 5, "active" => true}
      }

      {:ok, inserted} = SQLite.insert(store, entity)
      assert inserted.source_id == "s1"
      assert inserted.metadata["level"] == 5

      {:ok, [retrieved]} = SQLite.query(store, :entity, id: "e_meta")
      assert retrieved.metadata["level"] == 5
      assert retrieved.metadata["active"] == true
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

    test "queries entities by name", %{store: store} do
      SQLite.insert(store, %Entity{id: "e_n1", type: "person", name: "Diana"})
      SQLite.insert(store, %Entity{id: "e_n2", type: "person", name: "Eve"})
      {:ok, results} = SQLite.query(store, :entity, name: "Diana")
      assert length(results) == 1
      assert hd(results).id == "e_n1"
    end

    test "queries entities by metadata", %{store: store} do
      entity = %Entity{id: "e6", type: "person", name: "Dave", metadata: %{"dept" => "eng"}}
      SQLite.insert(store, entity)
      {:ok, results} = SQLite.query(store, :entity, [{:metadata, "dept", "eng"}])
      assert length(results) == 1
      assert hd(results).name == "Dave"
    end

    test "queries entities with no filters returns all", %{store: store} do
      SQLite.insert(store, %Entity{id: "e_a1", type: "person", name: "A1"})
      SQLite.insert(store, %Entity{id: "e_a2", type: "org", name: "A2"})
      {:ok, results} = SQLite.query(store, :entity, [])
      assert length(results) >= 2
    end

    test "queries entities with unknown filter ignores it", %{store: store} do
      SQLite.insert(store, %Entity{id: "e_unk", type: "person", name: "Unk"})
      {:ok, results} = SQLite.query(store, :entity, unknown_key: "val")
      assert length(results) == 1
    end

    test "query returns empty list for no matches", %{store: store} do
      {:ok, results} = SQLite.query(store, :entity, id: "nonexistent")
      assert results == []
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

    test "inserts fact with source_id and metadata", %{store: store} do
      fact = %Fact{
        id: "f_meta",
        subject: "X",
        predicate: "knows",
        object: "Y",
        source_id: "s1",
        metadata: %{"confidence" => 0.95}
      }

      {:ok, inserted} = SQLite.insert(store, fact)
      assert inserted.source_id == "s1"

      {:ok, [retrieved]} = SQLite.query(store, :fact, id: "f_meta")
      assert retrieved.metadata["confidence"] == 0.95
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

    test "queries facts by predicate", %{store: store} do
      SQLite.insert(store, %Fact{id: "f_pred1", subject: "A", predicate: "manages", object: "B"})

      SQLite.insert(store, %Fact{
        id: "f_pred2",
        subject: "C",
        predicate: "reports_to",
        object: "D"
      })

      {:ok, results} = SQLite.query(store, :fact, predicate: "manages")
      assert length(results) == 1
      assert hd(results).id == "f_pred1"
    end

    test "queries facts by object", %{store: store} do
      SQLite.insert(store, %Fact{id: "f_obj1", subject: "A", predicate: "works_at", object: "HQ"})

      SQLite.insert(store, %Fact{
        id: "f_obj2",
        subject: "B",
        predicate: "works_at",
        object: "Remote"
      })

      {:ok, results} = SQLite.query(store, :fact, object: "HQ")
      assert length(results) == 1
    end

    test "queries facts by source_id", %{store: store} do
      SQLite.insert(store, %Fact{
        id: "f_sid1",
        subject: "A",
        predicate: "p",
        object: "B",
        source_id: "src1"
      })

      SQLite.insert(store, %Fact{
        id: "f_sid2",
        subject: "C",
        predicate: "p",
        object: "D",
        source_id: "src2"
      })

      {:ok, results} = SQLite.query(store, :fact, source_id: "src1")
      assert length(results) == 1
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

    test "queries facts with no filters returns all", %{store: store} do
      SQLite.insert(store, %Fact{id: "f_all1", subject: "A", predicate: "p", object: "B"})
      SQLite.insert(store, %Fact{id: "f_all2", subject: "C", predicate: "q", object: "D"})
      {:ok, results} = SQLite.query(store, :fact, [])
      assert length(results) >= 2
    end

    test "updates a fact", %{store: store} do
      {:ok, fact} =
        SQLite.insert(store, %Fact{id: "f5", subject: "A", predicate: "p", object: "B"})

      {:ok, updated} = SQLite.update(store, %{fact | object: "C"})
      assert updated.object == "C"
    end

    test "deletes a fact", %{store: store} do
      SQLite.insert(store, %Fact{id: "f_del", subject: "A", predicate: "p", object: "B"})
      {:ok, :deleted} = SQLite.delete(store, :fact, "f_del")
      {:ok, []} = SQLite.query(store, :fact, id: "f_del")
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

    test "inserts event with source_id and metadata", %{store: store} do
      event = %Event{
        id: "ev_meta",
        event_type: "action",
        occurred_at: "2024-03-01T12:00:00Z",
        source_id: "s1",
        metadata: %{"browser" => "chrome"}
      }

      {:ok, inserted} = SQLite.insert(store, event)
      assert inserted.source_id == "s1"
      assert inserted.metadata == %{"browser" => "chrome"}
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

    test "queries events with no filters returns all", %{store: store} do
      SQLite.insert(store, %Event{id: "ev_all1", event_type: "a", occurred_at: "2024-01-01"})
      SQLite.insert(store, %Event{id: "ev_all2", event_type: "b", occurred_at: "2024-01-02"})
      {:ok, results} = SQLite.query(store, :event, [])
      assert length(results) >= 2
    end

    test "deletes an event", %{store: store} do
      SQLite.insert(store, %Event{id: "ev_del", event_type: "temp", occurred_at: "2024-01-01"})
      {:ok, :deleted} = SQLite.delete(store, :event, "ev_del")
      {:ok, []} = SQLite.query(store, :event, id: "ev_del")
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

    test "inserts source with metadata", %{store: store} do
      source = %Source{id: "s_meta", kind: "api", identifier: "v3", metadata: %{"env" => "prod"}}
      {:ok, inserted} = SQLite.insert(store, source)
      assert inserted.metadata["env"] == "prod"
    end

    test "updates a source", %{store: store} do
      {:ok, source} = SQLite.insert(store, %Source{id: "s3", kind: "api", identifier: "v1"})
      {:ok, updated} = SQLite.update(store, %{source | identifier: "v2"})
      assert updated.identifier == "v2"
    end

    test "queries sources by kind", %{store: store} do
      SQLite.insert(store, %Source{id: "s_k1", kind: "api", identifier: "a"})
      SQLite.insert(store, %Source{id: "s_k2", kind: "import", identifier: "b"})

      {:ok, results} = SQLite.query(store, :source, kind: "api")
      assert length(results) == 1
      assert hd(results).id == "s_k1"
    end

    test "queries sources by identifier", %{store: store} do
      SQLite.insert(store, %Source{id: "s_id1", kind: "api", identifier: "unique_id"})
      {:ok, results} = SQLite.query(store, :source, identifier: "unique_id")
      assert length(results) == 1
    end

    test "queries sources with no filters returns all", %{store: store} do
      SQLite.insert(store, %Source{id: "s_all1", kind: "a", identifier: "x"})
      SQLite.insert(store, %Source{id: "s_all2", kind: "b", identifier: "y"})
      {:ok, results} = SQLite.query(store, :source, [])
      assert length(results) >= 2
    end

    test "deletes a source", %{store: store} do
      SQLite.insert(store, %Source{id: "s_del", kind: "temp", identifier: "del"})
      {:ok, :deleted} = SQLite.delete(store, :source, "s_del")
      {:ok, []} = SQLite.query(store, :source, id: "s_del")
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

    test "inserts reflection with metadata", %{store: store} do
      reflection = %Reflection{
        id: "r_meta",
        content: "insight",
        metadata: %{"model" => "gpt-4"}
      }

      {:ok, inserted} = SQLite.insert(store, reflection)
      assert inserted.metadata["model"] == "gpt-4"
    end

    test "updates a reflection", %{store: store} do
      {:ok, reflection} = SQLite.insert(store, %Reflection{id: "r2", content: "Initial insight"})
      {:ok, updated} = SQLite.update(store, %{reflection | content: "Revised insight"})
      assert updated.content == "Revised insight"
    end

    test "queries reflections by content", %{store: store} do
      SQLite.insert(store, %Reflection{id: "r_c1", content: "specific pattern"})
      SQLite.insert(store, %Reflection{id: "r_c2", content: "other insight"})

      {:ok, results} = SQLite.query(store, :reflection, content: "specific pattern")
      assert length(results) == 1
      assert hd(results).id == "r_c1"
    end

    test "queries reflections with no filters returns all", %{store: store} do
      SQLite.insert(store, %Reflection{id: "r_all1", content: "a"})
      SQLite.insert(store, %Reflection{id: "r_all2", content: "b"})
      {:ok, results} = SQLite.query(store, :reflection, [])
      assert length(results) >= 2
    end

    test "deletes a reflection", %{store: store} do
      SQLite.insert(store, %Reflection{id: "r_del", content: "temp"})
      {:ok, :deleted} = SQLite.delete(store, :reflection, "r_del")
      {:ok, []} = SQLite.query(store, :reflection, id: "r_del")
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
