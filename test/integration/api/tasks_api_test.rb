require "test_helper"

class Api::TasksApiTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_token = ApiToken.create_for_user!(@alice, name: "hermes-vm").raw_token
    @bob_token   = ApiToken.create_for_user!(@bob).raw_token
    @task = @alice.tasks.create!(title: "Write a YouTube script")
  end

  def headers(token = @alice_token)
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  test "no token → 401" do
    get "/api/v1/tasks"
    assert_response :unauthorized
  end

  test "POST creates a task" do
    assert_difference -> { @alice.tasks.count }, 1 do
      post "/api/v1/tasks", params: { title: "Edit thumbnail", status: "doing" }.to_json, headers: headers
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Edit thumbnail", body["title"]
    assert_equal "doing", body["status"]
  end

  test "index lists own tasks and filters by status" do
    @alice.tasks.create!(title: "in review", status: "review")
    @bob.tasks.create!(title: "bob")
    get "/api/v1/tasks", headers: headers
    assert_equal 2, JSON.parse(response.body).size

    get "/api/v1/tasks", params: { status: "review" }, headers: headers
    list = JSON.parse(response.body)
    assert_equal 1, list.size
    assert_equal "review", list[0]["status"]
  end

  test "show includes comments and linked documents" do
    @task.task_comments.create!(body: "starting", author_kind: "agent", author_name: "hermes-vm")
    doc = @alice.documents.create!(body: "# Script")
    @task.link_document(doc)

    get "/api/v1/tasks/#{@task.public_token}", headers: headers
    body = JSON.parse(response.body)
    assert_equal 1, body["comments"].size
    assert_equal "hermes-vm", body["comments"][0]["author"]
    assert_equal "agent", body["comments"][0]["author_kind"]
    assert_equal 1, body["documents"].size
    assert_equal doc.public_token, body["documents"][0]["id"]
  end

  test "PATCH updates status; invalid status is ignored" do
    patch "/api/v1/tasks/#{@task.public_token}", params: { status: "review" }.to_json, headers: headers
    assert_equal "review", @task.reload.status

    patch "/api/v1/tasks/#{@task.public_token}", params: { status: "bogus" }.to_json, headers: headers
    assert_response :success
    assert_equal "review", @task.reload.status
  end

  test "DELETE removes the task" do
    assert_difference -> { Task.count }, -1 do
      delete "/api/v1/tasks/#{@task.public_token}", headers: headers
    end
    assert_response :no_content
  end

  test "cross-user task → 404" do
    get "/api/v1/tasks/#{@task.public_token}", headers: headers(@bob_token)
    assert_response :not_found
  end

  test "agent comment records the token name as author" do
    assert_difference -> { @task.task_comments.count }, 1 do
      post "/api/v1/tasks/#{@task.public_token}/comments",
           params: { body: "Draft is ready for review" }.to_json, headers: headers
    end
    assert_response :created
    comment = @task.task_comments.last
    assert_equal "agent", comment.author_kind
    assert_equal "hermes-vm", comment.author_name
    assert_equal "hermes-vm", JSON.parse(response.body)["author"]
  end

  test "blank agent comment → 422" do
    post "/api/v1/tasks/#{@task.public_token}/comments", params: { body: "" }.to_json, headers: headers
    assert_response :unprocessable_entity
  end

  test "link an existing document to a task" do
    doc = @alice.documents.create!(body: "# Existing")
    post "/api/v1/tasks/#{@task.public_token}/documents",
         params: { document_id: doc.public_token }.to_json, headers: headers
    assert_response :created
    assert_equal [ doc ], @task.reload.documents.to_a
  end

  test "create a document and link it in one call (the agent flow)" do
    assert_difference [ -> { @alice.documents.count }, -> { @task.task_documents.count } ], 1 do
      post "/api/v1/tasks/#{@task.public_token}/documents",
           params: { body: "# YouTube script\n\nIntro..." }.to_json, headers: headers
    end
    assert_response :created
    assert_equal "YouTube script", JSON.parse(response.body)["title"]
    assert_equal 1, @task.reload.documents.size
  end

  test "linking with neither document_id nor body → 422" do
    post "/api/v1/tasks/#{@task.public_token}/documents", params: {}.to_json, headers: headers
    assert_response :unprocessable_entity
  end

  test "cannot link another user's document" do
    bobs_doc = @bob.documents.create!(body: "# Bob")
    post "/api/v1/tasks/#{@task.public_token}/documents",
         params: { document_id: bobs_doc.public_token }.to_json, headers: headers
    assert_response :not_found
    assert_empty @task.reload.documents
  end

  test "unlink a document without deleting it" do
    doc = @alice.documents.create!(body: "# Linked")
    @task.link_document(doc)
    assert_difference -> { Document.count }, 0 do
      delete "/api/v1/tasks/#{@task.public_token}/documents/#{doc.public_token}", headers: headers
    end
    assert_response :no_content
    assert_empty @task.reload.documents
  end
end
