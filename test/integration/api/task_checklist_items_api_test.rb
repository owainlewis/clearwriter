require "test_helper"

class Api::TaskChecklistItemsApiTest < ActionDispatch::IntegrationTest
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
    get "/api/v1/tasks/#{@task.public_token}/checklist_items"
    assert_response :unauthorized
  end

  test "create, list, toggle, and delete a checklist item" do
    assert_difference -> { @task.checklist_items.count }, 1 do
      post "/api/v1/tasks/#{@task.public_token}/checklist_items",
        params: { content: "Write the intro" }.to_json, headers: headers
    end
    assert_response :created
    item = JSON.parse(response.body)
    assert_equal "Write the intro", item["content"]
    assert_equal false, item["done"]

    get "/api/v1/tasks/#{@task.public_token}/checklist_items", headers: headers
    assert_response :success
    assert_equal 1, JSON.parse(response.body).size

    patch "/api/v1/tasks/#{@task.public_token}/checklist_items/#{item['id']}",
      params: { done: true }.to_json, headers: headers
    assert_response :success
    assert_equal true, JSON.parse(response.body)["done"]

    assert_difference -> { @task.checklist_items.count }, -1 do
      delete "/api/v1/tasks/#{@task.public_token}/checklist_items/#{item['id']}", headers: headers
    end
    assert_response :no_content
  end

  test "task detail includes the checklist and a summary" do
    @task.checklist_items.create!(content: "a", done: true)
    @task.checklist_items.create!(content: "b")

    get "/api/v1/tasks/#{@task.public_token}", headers: headers
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal({ "done" => 1, "total" => 2 }, body["checklist_summary"])
    assert_equal 2, body["checklist"].size
    assert_equal "a", body["checklist"].first["content"]
  end

  test "another user's task is not found" do
    post "/api/v1/tasks/#{@task.public_token}/checklist_items",
      params: { content: "x" }.to_json, headers: headers(@bob_token)
    assert_response :not_found
  end
end
