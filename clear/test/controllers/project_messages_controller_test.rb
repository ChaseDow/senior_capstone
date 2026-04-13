require "test_helper"

class ProjectMessagesControllerTest < ActionDispatch::IntegrationTest
  test "should create project_message" do
    post project_project_messages_url(projects(:one)), params: { project_message: { body: "Hello" } }
    assert_response :redirect
  end
end
