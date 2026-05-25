require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @collection = @user.collections.create!(name: "YouTube video")
  end

  test "create assigns a 22-char base58 public_token" do
    assert_equal 22, @collection.public_token.length
    assert_match(/\A[1-9A-HJ-NP-Za-km-z]+\z/, @collection.public_token)
  end

  test "to_param returns public_token" do
    assert_equal @collection.public_token, @collection.to_param
  end

  test "name is stripped" do
    c = @user.collections.create!(name: "  spaced  ")
    assert_equal "spaced", c.name
  end

  test "display_name falls back when blank" do
    c = @user.collections.create!(name: "")
    assert_equal Collection::NAME_FALLBACK, c.display_name
  end

  test "add_document appends in order and is idempotent" do
    a = @user.documents.create!(body: "# A")
    b = @user.documents.create!(body: "# B")

    @collection.add_document(a)
    @collection.add_document(b)
    @collection.add_document(a) # no-op

    assert_equal [ a, b ], @collection.reload.documents.to_a
    assert_equal 2, @collection.collection_documents.count
  end

  test "remove_document detaches without deleting the document" do
    a = @user.documents.create!(body: "# A")
    @collection.add_document(a)

    assert_difference -> { Document.count }, 0 do
      @collection.remove_document(a)
    end
    assert_empty @collection.reload.documents
    assert Document.exists?(a.id)
  end

  test "deleting a collection keeps its documents" do
    a = @user.documents.create!(body: "# A")
    @collection.add_document(a)

    assert_difference -> { Document.count }, 0 do
      assert_difference -> { CollectionDocument.count }, -1 do
        @collection.destroy!
      end
    end
    assert Document.exists?(a.id)
  end

  test "deleting a document removes its memberships" do
    a = @user.documents.create!(body: "# A")
    @collection.add_document(a)

    assert_difference -> { CollectionDocument.count }, -1 do
      a.destroy!
    end
    assert_empty @collection.reload.documents
  end
end
