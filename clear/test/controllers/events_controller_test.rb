require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :users

  setup do
    @user = users(:one)
    sign_in @user
    @event = Event.create!(user: @user, title: "Existing event", starts_at: Time.current)
  end

  test "should get index" do
    get events_url
    assert_response :success
  end

  test "should get new" do
    get new_event_url
    assert_response :success
  end

  test "should create event" do
    assert_difference("Event.count", 1) do
      post events_url, params: {
        event: {
          title: "Created event",
          starts_at: Time.current,
          ends_at: Time.current + 1.hour,
          location: "Library",
          description: "Bring notes"
        }
      }
    end

    created = Event.order(:id).last
    assert_redirected_to event_url(created)
  end

  test "should show event" do
    get event_url(@event)
    assert_response :success
  end

  test "should get edit" do
    get edit_event_url(@event)
    assert_response :success
  end

  test "should update event" do
    patch event_url(@event), params: { event: { title: "Updated title" } }
    assert_redirected_to event_url(@event)
    @event.reload
    assert_equal "Updated title", @event.title
  end

  test "should destroy event" do
    assert_difference("Event.count", -1) do
      delete event_url(@event)
    end

    assert_redirected_to events_url
  end
end
