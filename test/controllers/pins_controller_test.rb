require "test_helper"

class PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @doc   = @alice.documents.create!(body: "# Alice doc")
  end

  test "pinning a doc sets pinned and redirects back" do
    sign_in_as @alice
    post document_pin_path(@doc), headers: { "HTTP_REFERER" => documents_path }
    assert_redirected_to documents_path
    assert @doc.reload.pinned
  end

  test "unpinning a doc clears pinned" do
    @doc.update!(pinned: true)
    sign_in_as @alice
    delete document_pin_path(@doc), headers: { "HTTP_REFERER" => documents_path }
    assert_redirected_to documents_path
    assert_not @doc.reload.pinned
  end

  test "cannot pin another user's doc (404, no IDOR)" do
    bobs_doc = @bob.documents.create!(body: "Bob")
    sign_in_as @alice
    post document_pin_path(bobs_doc)
    assert_response :not_found
    assert_not bobs_doc.reload.pinned
  end

  test "pinning requires authentication" do
    post document_pin_path(@doc)
    assert_redirected_to new_session_path
  end
end
