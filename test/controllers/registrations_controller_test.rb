require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "GET /sign_up redirects to sign in while signups are closed" do
    get new_registration_path
    assert_redirected_to new_session_path
    assert_equal "Sign ups are currently closed.", flash[:alert]
  end

  test "POST /sign_up does not create a user while signups are closed" do
    assert_no_difference -> { User.count } do
      post registration_path, params: {
        user: { email_address: "new@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_redirected_to new_session_path
    assert_equal "Sign ups are currently closed.", flash[:alert]
    assert_nil cookies[:session_id].presence
  end

  test "POST /sign_up does not create users for invalid params while signups are closed" do
    assert_no_difference -> { User.count } do
      post registration_path, params: {
        user: { email_address: "x@example.com", password: "password123", password_confirmation: "different" }
      }
    end

    assert_redirected_to new_session_path
  end
end
