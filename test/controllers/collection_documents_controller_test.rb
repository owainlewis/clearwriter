require "test_helper"

class CollectionDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @collection = @alice.collections.create!(name: "Bundle")
    @doc = @alice.documents.create!(body: "# Alice doc")
  end

  test "adds an existing doc to the collection" do
    sign_in_as @alice
    assert_difference -> { @collection.documents.count }, 1 do
      post collection_documents_path(@collection), params: { document_id: @doc.public_token }
    end
    assert_redirected_to collection_path(@collection)
  end

  test "removes a doc from the collection without deleting it" do
    @collection.add_document(@doc)
    sign_in_as @alice
    assert_difference -> { @collection.documents.count }, -1 do
      delete collection_document_path(@collection, @doc)
    end
    assert Document.exists?(@doc.id)
  end

  test "cannot add another user's document" do
    bobs_doc = @bob.documents.create!(body: "Bob")
    sign_in_as @alice
    post collection_documents_path(@collection), params: { document_id: bobs_doc.public_token }
    assert_response :not_found
    assert_empty @collection.reload.documents
  end

  test "cannot add to another user's collection" do
    bobs = @bob.collections.create!(name: "Bob")
    sign_in_as @alice
    post collection_documents_path(bobs), params: { document_id: @doc.public_token }
    assert_response :not_found
  end

  test "search returns matching linkable documents and excludes linked ones" do
    sign_in_as @alice
    findable = @alice.documents.create!(body: "# Findable script")
    @collection.add_document(@doc) # already linked → must not appear

    get search_collection_documents_path(@collection), params: { q: "Findable" }
    assert_response :success
    assert_includes response.body, "Findable script"
    assert_not_includes response.body, @doc.public_token
  end

  test "search is owner-scoped" do
    @bob.documents.create!(body: "# Bob secret findable")
    sign_in_as @alice
    get search_collection_documents_path(@collection), params: { q: "findable" }
    assert_not_includes response.body, "Bob secret findable"
  end

  test "linking via turbo_stream streams the row in place" do
    sign_in_as @alice
    post collection_documents_path(@collection),
         params: { document_id: @doc.public_token }, as: :turbo_stream
    assert_response :success
    assert_includes @collection.reload.documents, @doc
    assert_match "linked-doc-#{@doc.public_token}", response.body
    assert_match "result-#{@doc.public_token}", response.body # removal target
  end

  test "unlinking via turbo_stream removes the row" do
    @collection.add_document(@doc)
    sign_in_as @alice
    delete collection_document_path(@collection, @doc), as: :turbo_stream
    assert_response :success
    assert_match "linked-doc-#{@doc.public_token}", response.body
    assert_not_includes @collection.reload.documents, @doc
  end
end
