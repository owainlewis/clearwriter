require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "password reset email is sent synchronously" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post passwords_path, params: { email_address: users(:alice).email_address }
    end

    assert_redirected_to new_session_path
    assert_equal users(:alice).email_address, ActionMailer::Base.deliveries.last.to.first
  end

  test "password reset does not reveal unknown accounts" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      post passwords_path, params: { email_address: "missing@example.com" }
    end

    assert_redirected_to new_session_path
  end
end
