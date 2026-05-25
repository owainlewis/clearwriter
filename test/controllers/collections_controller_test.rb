require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @collection = @alice.collections.create!(name: "YouTube video")
  end

  test "signed-out requests redirect to sign in" do
    get collections_path
    assert_redirected_to new_session_path
  end

  test "index lists own collections only" do
    @bob.collections.create!(name: "Bob secret bundle")
    sign_in_as @alice
    get collections_path
    assert_response :success
    assert_includes response.body, "YouTube video"
    assert_not_includes response.body, "Bob secret bundle"
  end

  test "index renders a create form posting collection[name]" do
    sign_in_as @alice
    get collections_path
    assert_select "form[action=?][method=post]", collections_path do
      assert_select "input[name=?]", "collection[name]"
    end
  end

  test "create makes a collection and redirects to it" do
    sign_in_as @alice
    assert_difference -> { @alice.collections.count }, 1 do
      post collections_path, params: { collection: { name: "Photos" } }
    end
    assert_redirected_to collection_path(@alice.collections.order(:created_at).last)
  end

  test "show lists member documents" do
    doc = @alice.documents.create!(body: "# In the bundle")
    @collection.add_document(doc)
    sign_in_as @alice
    get collection_path(@collection)
    assert_response :success
    assert_includes response.body, "In the bundle"
  end

  test "update renames the collection" do
    sign_in_as @alice
    patch collection_path(@collection), params: { collection: { name: "Renamed" } }
    assert_redirected_to collection_path(@collection)
    assert_equal "Renamed", @collection.reload.name
  end

  test "destroy removes the collection but keeps docs" do
    doc = @alice.documents.create!(body: "# Keep me")
    @collection.add_document(doc)
    sign_in_as @alice
    delete collection_path(@collection)
    assert_redirected_to collections_path
    assert_not Collection.exists?(@collection.id)
    assert Document.exists?(doc.id)
  end

  test "cross-user show returns 404" do
    bobs = @bob.collections.create!(name: "Bob")
    sign_in_as @alice
    get collection_path(bobs)
    assert_response :not_found
  end

  test "cross-user destroy returns 404" do
    bobs = @bob.collections.create!(name: "Bob")
    sign_in_as @alice
    delete collection_path(bobs)
    assert_response :not_found
    assert Collection.exists?(bobs.id)
  end
end
