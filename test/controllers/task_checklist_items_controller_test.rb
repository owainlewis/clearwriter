require "test_helper"

class TaskChecklistItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @task  = @alice.tasks.create!(title: "Write script")
  end

  test "signed-out requests redirect to sign in" do
    post task_checklist_items_path(@task), params: { task_checklist_item: { content: "x" } }
    assert_redirected_to new_session_path
  end

  test "create adds an item and streams the checklist back" do
    sign_in_as @alice
    assert_difference -> { @task.checklist_items.count }, 1 do
      post task_checklist_items_path(@task),
        params: { task_checklist_item: { content: "Write the intro" } }, as: :turbo_stream
    end
    assert_response :success
    assert_match "checklist", response.body
    assert_includes response.body, "Write the intro"
  end

  test "blank content is ignored" do
    sign_in_as @alice
    assert_no_difference -> { @task.checklist_items.count } do
      post task_checklist_items_path(@task),
        params: { task_checklist_item: { content: "   " } }, as: :turbo_stream
    end
  end

  test "update toggles done" do
    sign_in_as @alice
    item = @task.checklist_items.create!(content: "Step")
    patch task_checklist_item_path(@task, item),
      params: { task_checklist_item: { done: true } }, as: :turbo_stream
    assert_response :success
    assert item.reload.done
  end

  test "destroy removes the item" do
    sign_in_as @alice
    item = @task.checklist_items.create!(content: "Step")
    assert_difference -> { @task.checklist_items.count }, -1 do
      delete task_checklist_item_path(@task, item), as: :turbo_stream
    end
    assert_response :success
  end

  test "another user's task is not found" do
    sign_in_as @bob
    post task_checklist_items_path(@task),
      params: { task_checklist_item: { content: "x" } }, as: :turbo_stream
    assert_response :not_found
  end
end
