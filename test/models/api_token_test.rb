require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  setup { @user = users(:alice) }

  test "create_for_user! returns raw token once with pair_ prefix" do
    record = ApiToken.create_for_user!(@user, name: "ci")
    assert_match(/\Apair_[A-Za-z0-9_\-]+\z/, record.raw_token)
    assert_equal "ci", record.name
  end

  test "raw token is never persisted; only the digest" do
    record = ApiToken.create_for_user!(@user)
    raw = record.raw_token
    record.reload
    assert_not_equal raw, record.token_digest
    assert_equal Digest::SHA256.hexdigest(raw), record.token_digest
  end

  test "authenticate succeeds with the raw token" do
    record = ApiToken.create_for_user!(@user)
    assert_equal record, ApiToken.authenticate(record.raw_token)
  end

  test "authenticate fails on a wrong token" do
    assert_nil ApiToken.authenticate("pair_definitely-not-real")
    assert_nil ApiToken.authenticate(nil)
    assert_nil ApiToken.authenticate("")
  end

  test "touch_last_used! sets last_used_at" do
    record = ApiToken.create_for_user!(@user)
    assert_nil record.last_used_at
    record.touch_last_used!
    assert record.reload.last_used_at
  end
end
