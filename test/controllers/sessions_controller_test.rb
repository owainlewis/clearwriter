require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /sign_in renders" do
    get new_session_path
    assert_response :success
    assert_includes response.body, "Sign in"
    assert_select "form[action=?]", session_path
    assert_select "a[href=?]", new_registration_path, count: 0
  end

  test "POST /sign_in with correct credentials redirects and sets session cookie" do
    post session_path, params: { email_address: "alice@example.com", password: "password123" }
    assert_response :redirect
    assert cookies[:session_id].present?
  end

  test "POST /sign_in with wrong password redirects back to sign in" do
    post session_path, params: { email_address: "alice@example.com", password: "wrong" }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence
  end

  test "DELETE /sign_out destroys the session" do
    sign_in_as users(:alice)
    assert_difference -> { Session.count }, -1 do
      delete sign_out_path
    end
    assert_redirected_to new_session_path
  end
end
