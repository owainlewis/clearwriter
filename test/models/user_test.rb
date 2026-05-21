require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is normalized to lowercase / trimmed" do
    u = User.create!(email_address: "  MiXeD@Example.COM ", password: "password123", password_confirmation: "password123")
    assert_equal "mixed@example.com", u.email_address
  end

  test "authenticate_by accepts the right password" do
    assert User.authenticate_by(email_address: "alice@example.com", password: "password123")
  end

  test "authenticate_by rejects the wrong password" do
    assert_nil User.authenticate_by(email_address: "alice@example.com", password: "wrong")
  end

  test "email_address must be unique" do
    dup = User.new(email_address: "alice@example.com", password: "password123", password_confirmation: "password123")
    assert_not dup.valid?
    assert_includes dup.errors[:email_address], "has already been taken"
  end
end
