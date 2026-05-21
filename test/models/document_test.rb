require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  setup { @user = users(:alice) }

  test "create assigns a 22-char base58 public_token" do
    doc = @user.documents.create!(body: "hi")
    assert_equal 22, doc.public_token.length
    assert_match(/\A[1-9A-HJ-NP-Za-km-z]+\z/, doc.public_token,
                 "token should use base58 alphabet (no 0/O/l/I)")
  end

  test "public_token is unique" do
    a = @user.documents.create!(body: "a")
    dup = @user.documents.build(body: "b", public_token: a.public_token)
    assert_not dup.valid?
    assert_includes dup.errors[:public_token], "has already been taken"
  end

  test "to_param returns public_token so URLs use it as :id" do
    doc = @user.documents.create!(body: "x")
    assert_equal doc.public_token, doc.to_param
  end

  test "title is derived from first H1" do
    doc = @user.documents.create!(body: "# Hello world\nbody")
    assert_equal "Hello world", doc.title
  end

  test "title falls back to first non-empty line when no H1" do
    doc = @user.documents.create!(body: "\n\nJust a sentence\nrest")
    assert_equal "Just a sentence", doc.title
  end

  test "title fallback truncates very long first lines" do
    long = "a" * 200
    doc = @user.documents.create!(body: long)
    assert_operator doc.title.length, :<=, Document::TITLE_FALLBACK_LIMIT
    assert doc.title.end_with?("…")
  end

  test "title is empty when body is blank" do
    doc = @user.documents.create!(body: "")
    assert_equal "", doc.title
  end

  test "title updates whenever body changes" do
    doc = @user.documents.create!(body: "# First")
    doc.update!(body: "# Second")
    assert_equal "Second", doc.title
  end

  test "body within byte limit accepts 5MB ASCII" do
    doc = @user.documents.new(body: "a" * Document::MAX_BODY_BYTES)
    assert doc.valid?
  end

  test "body over byte limit fails — counts bytes, not chars" do
    # 2M emoji × 4 bytes each = 8MB; would pass a char-length check.
    over = "😀" * (2 * 1024 * 1024)
    doc = @user.documents.new(body: over)
    assert_not doc.valid?
    assert_includes doc.errors[:body].first, "5 MB"
  end

  test "with_tag scope returns only matching docs" do
    @user.documents.create!(body: "a", tags_text: "onboarding, claude")
    @user.documents.create!(body: "b", tags_text: "newsletter")
    assert_equal 1, @user.documents.with_tag("onboarding").count
    assert_equal 0, @user.documents.with_tag("missing").count
  end

  test "tags_text= normalises: lowercases, trims, dedupes, strips leading #" do
    doc = @user.documents.create!(body: "x", tags_text: "Onboarding, claude, CLAUDE,  #sop  ")
    assert_equal %w[onboarding claude sop], doc.tags
  end

  test "User#documents cascades destroy" do
    u = User.create!(email_address: "tmp@example.com", password: "password123", password_confirmation: "password123")
    u.documents.create!(body: "x")
    assert_difference -> { Document.count }, -1 do
      u.destroy
    end
  end

  test "different users get distinct public_tokens" do
    a = users(:alice).documents.create!(body: "x")
    b = users(:bob).documents.create!(body: "x")
    assert_not_equal a.public_token, b.public_token
  end
end
