require "test_helper"

class ProjectMessagesControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get project_messages_create_url
    assert_response :success
  end
end
