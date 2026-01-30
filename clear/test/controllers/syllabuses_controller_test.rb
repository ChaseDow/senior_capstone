# Frozen_string_literal:true

require "test_helper"

class SyllabusesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :users, :syllabuses

  setup do
    @user     = users(:one)
    @syllabus = syllabuses(:one) # must belong to users(:one)
    sign_in @user
  end

  test "should get index" do
    get syllabuses_url
    assert_response :success
  end

  test "index only shows current user's syllabuses" do
    other = syllabuses(:two) # belongs to users(:two)

    get syllabuses_url
    assert_response :success

    assert_includes @response.body, @syllabus.title
    refute_includes @response.body, other.title
  end

  test "should get new" do
    get new_syllabus_url
    assert_response :success
  end

  test "should create syllabus and attach to current user" do
    assert_difference("Syllabus.count", 1) do
      post syllabuses_url, params: { syllabus: { title: "My Syllabus" } }
    end

    created = Syllabus.order(:created_at).last
    assert_redirected_to syllabus_url(created)
    assert_equal @user.id, created.user_id
  end

  test "should show syllabus" do
    get syllabus_url(@syllabus)
    assert_response :success
  end

  test "should NOT show another user's syllabus" do
    other = syllabuses(:two)

    get syllabus_url(other)
    assert_response :not_found
  end

  test "should destroy syllabus" do
    assert_difference("Syllabus.count", -1) do
      delete syllabus_url(@syllabus)
    end

    assert_redirected_to syllabuses_url
  end

  test "should NOT destroy another user's syllabus" do
    other = syllabuses(:two)

    assert_no_difference("Syllabus.count") do
      delete syllabus_url(other)
    end

    assert_response :not_found
  end
end
