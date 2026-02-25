require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
  end

  test "should get show" do
    get profile_url
    assert_response :success
  end

  test "should get edit" do
    get edit_profile_url
    assert_response :success
  end
end
