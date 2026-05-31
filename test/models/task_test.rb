require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup { @user = users(:alice) }

  test "create assigns a public_token and defaults to todo" do
    t = @user.tasks.create!(title: "Write script")
    assert_equal 22, t.public_token.length
    assert_equal "todo", t.status
  end

  test "rejects an unknown status" do
    t = @user.tasks.build(title: "x", status: "nope")
    assert_not t.valid?
    assert_includes t.errors[:status], "is not included in the list"
  end

  test "create defaults priority to none and rejects unknown values" do
    assert_equal "none", @user.tasks.create!(title: "x").priority

    t = @user.tasks.build(title: "y", priority: "p9")
    assert_not t.valid?
    assert_includes t.errors[:priority], "is not included in the list"
  end

  test "focus_order sorts by priority then most-recent, none last" do
    p3   = @user.tasks.create!(title: "p3", priority: "p3")
    p0   = @user.tasks.create!(title: "p0", priority: "p0")
    p1   = @user.tasks.create!(title: "p1", priority: "p1")
    none = @user.tasks.create!(title: "none")
    assert_equal [ p0, p1, p3, none ], @user.tasks.focus_order.to_a
  end

  test "new tasks append to the end of their own column" do
    a = @user.tasks.create!(title: "a", status: "todo")
    b = @user.tasks.create!(title: "b", status: "todo")
    c = @user.tasks.create!(title: "c", status: "doing")
    assert_equal 0, a.position
    assert_equal 1, b.position
    assert_equal 0, c.position, "a different column starts its own numbering"
  end

  test "display_title falls back when blank" do
    assert_equal Task::TITLE_FALLBACK, @user.tasks.create!(title: "").display_title
  end

  test "link_document is idempotent; unlink keeps the document" do
    t = @user.tasks.create!(title: "t")
    d = @user.documents.create!(body: "# Doc")
    t.link_document(d)
    t.link_document(d)
    assert_equal [ d ], t.documents.to_a
    assert_equal 1, t.task_documents.count

    assert_difference -> { Document.count }, 0 do
      t.unlink_document(d)
    end
    assert_empty t.reload.documents
    assert Document.exists?(d.id)
  end

  test "deleting a task removes its comments and links but keeps the documents" do
    t = @user.tasks.create!(title: "t")
    d = @user.documents.create!(body: "# Doc")
    t.link_document(d)
    t.task_comments.create!(body: "hi", author_kind: "human")

    assert_difference [ -> { TaskComment.count }, -> { TaskDocument.count } ], -1 do
      assert_difference -> { Document.count }, 0 do
        t.destroy!
      end
    end
    assert Document.exists?(d.id)
  end

  test "comment author display: human vs agent" do
    t = @user.tasks.create!(title: "t")
    human = t.task_comments.create!(body: "ok", author_kind: "human")
    agent = t.task_comments.create!(body: "done", author_kind: "agent", author_name: "hermes-vm")
    assert_equal "You", human.display_author
    assert_equal "hermes-vm", agent.display_author
    assert agent.agent?
  end
end
