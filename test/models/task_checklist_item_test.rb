require "test_helper"

class TaskChecklistItemTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @task = @user.tasks.create!(title: "Write script")
  end

  test "create assigns a public_token and defaults to not done" do
    item = @task.checklist_items.create!(content: "Outline the intro")
    assert_equal 22, item.public_token.length
    assert_not item.done
  end

  test "content is required and stripped" do
    blank = @task.checklist_items.build(content: "   ")
    assert_not blank.valid?

    item = @task.checklist_items.create!(content: "  Trim whitespace  ")
    assert_equal "Trim whitespace", item.content
  end

  test "new items append to the end of the checklist" do
    a = @task.checklist_items.create!(content: "a")
    b = @task.checklist_items.create!(content: "b")
    c = @task.checklist_items.create!(content: "c")
    assert_equal [ 0, 1, 2 ], [ a.position, b.position, c.position ]
  end

  test "checklist_progress counts done over total" do
    @task.checklist_items.create!(content: "a", done: true)
    @task.checklist_items.create!(content: "b")
    assert_equal [ 1, 2 ], @task.reload.checklist_progress
  end

  test "deleting a task removes its checklist items" do
    @task.checklist_items.create!(content: "a")
    assert_difference -> { TaskChecklistItem.count }, -1 do
      @task.destroy!
    end
  end
end
