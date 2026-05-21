require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "GET /sign_up renders" do
    get new_registration_path
    assert_response :success
    assert_includes response.body, "account"
  end

  test "POST /sign_up creates a user and signs them in" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: {
        user: { email_address: "new@example.com", password: "password123", password_confirmation: "password123" }
      }
    end
    assert_response :redirect
    assert cookies[:session_id].present?
  end

  test "POST /sign_up rejects mismatched confirmations" do
    assert_no_difference -> { User.count } do
      post registration_path, params: {
        user: { email_address: "x@example.com", password: "password123", password_confirmation: "different" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "POST /sign_up rejects duplicate emails" do
    assert_no_difference -> { User.count } do
      post registration_path, params: {
        user: { email_address: "alice@example.com", password: "password123", password_confirmation: "password123" }
      }
    end
  end
end
