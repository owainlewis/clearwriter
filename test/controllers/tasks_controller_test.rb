require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @task  = @alice.tasks.create!(title: "Write script")
  end

  test "signed-out requests redirect to sign in" do
    get tasks_path
    assert_redirected_to new_session_path
  end

  test "board shows the four columns and the user's task" do
    sign_in_as @alice
    get tasks_path
    assert_response :success
    assert_includes response.body, "Write script"
    %w[Todo Doing Review Done].each { |label| assert_includes response.body, label }
  end

  test "create adds a task in the given column" do
    sign_in_as @alice
    assert_difference -> { @alice.tasks.count }, 1 do
      post tasks_path, params: { task: { title: "New", status: "doing" } }
    end
    assert_redirected_to tasks_path
    assert_equal "doing", @alice.tasks.order(:created_at).last.status
  end

  test "create ignores an invalid status and defaults to todo" do
    sign_in_as @alice
    post tasks_path, params: { task: { title: "X", status: "bogus" } }
    assert_equal "todo", @alice.tasks.order(:created_at).last.status
  end

  test "update changes status and description" do
    sign_in_as @alice
    patch task_path(@task), params: { task: { status: "done", description: "did it" } }
    assert_redirected_to task_path(@task)
    @task.reload
    assert_equal "done", @task.status
    assert_equal "did it", @task.description
  end

  test "reorder moves cards and renumbers, owner-scoped" do
    sign_in_as @alice
    a = @alice.tasks.create!(title: "a", status: "todo")
    b = @alice.tasks.create!(title: "b", status: "todo")
    post reorder_tasks_path, params: { status: "doing", ids: [ b.public_token, a.public_token ] }, as: :json
    assert_response :no_content
    assert_equal [ "doing", 0 ], [ b.reload.status, b.position ]
    assert_equal [ "doing", 1 ], [ a.reload.status, a.position ]
  end

  test "reorder rejects an unknown status" do
    sign_in_as @alice
    post reorder_tasks_path, params: { status: "nope", ids: [] }, as: :json
    assert_response :unprocessable_entity
  end

  test "reorder ignores tasks owned by another user" do
    bobs = @bob.tasks.create!(title: "bob")
    sign_in_as @alice
    post reorder_tasks_path, params: { status: "done", ids: [ bobs.public_token ] }, as: :json
    assert_response :no_content
    assert_not_equal "done", bobs.reload.status
  end

  test "cross-user show returns 404" do
    bobs = @bob.tasks.create!(title: "bob")
    sign_in_as @alice
    get task_path(bobs)
    assert_response :not_found
  end

  test "destroy removes the task" do
    sign_in_as @alice
    delete task_path(@task)
    assert_redirected_to tasks_path
    assert_not Task.exists?(@task.id)
  end

  test "web comment records a human author; blank is ignored" do
    sign_in_as @alice
    assert_difference -> { @task.task_comments.count }, 1 do
      post task_comments_path(@task), params: { task_comment: { body: "looks good" } }
    end
    assert_equal "human", @task.task_comments.last.author_kind

    assert_no_difference -> { @task.task_comments.count } do
      post task_comments_path(@task), params: { task_comment: { body: "   " } }
    end
  end

  test "linking and unlinking a document from the web" do
    sign_in_as @alice
    d = @alice.documents.create!(body: "# D")
    post task_documents_path(@task), params: { document_id: d.public_token }
    assert_includes @task.reload.documents, d
    delete task_document_path(@task, d)
    assert_not_includes @task.reload.documents, d
  end

  test "cannot link another user's document" do
    bobs_doc = @bob.documents.create!(body: "# Bob")
    sign_in_as @alice
    post task_documents_path(@task), params: { document_id: bobs_doc.public_token }
    assert_response :not_found
  end
end
