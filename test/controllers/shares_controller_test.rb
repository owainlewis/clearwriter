require "test_helper"

class SharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @doc = @alice.documents.create!(body: "x")
  end

  test "create flips is_public to true" do
    sign_in_as @alice
    post document_share_path(@doc)
    assert_redirected_to edit_document_path(@doc)
    assert @doc.reload.is_public
  end

  test "destroy flips is_public to false" do
    @doc.update!(is_public: true)
    sign_in_as @alice
    delete document_share_path(@doc)
    assert_redirected_to edit_document_path(@doc)
    assert_not @doc.reload.is_public
  end

  test "cross-user share returns 404" do
    sign_in_as @bob
    post document_share_path(@doc)
    assert_response :not_found
    assert_not @doc.reload.is_public
  end
end
