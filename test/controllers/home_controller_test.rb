require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "signed-out root renders landing page" do
    get root_path

    assert_response :success
    assert_select "h1", /A workspace for you/
    assert_select "a[href=?]", new_session_path, text: "Sign in"
    assert_select "a[href=?]", new_registration_path, count: 0
    assert_includes response.body, "shared workspace"
    assert_includes response.body, "Claude Code"
  end

  test "signed-in root redirects to documents" do
    sign_in_as users(:alice)

    get root_path

    assert_redirected_to documents_path
  end
end
