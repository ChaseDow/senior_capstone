require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user

    @event = Event.create!(
      title: "Existing event",
      starts_at: Time.current,
      user: @user
    )
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

    assert_redirected_to event_url(Event.last)

    # Optional but useful: ensure it's owned by the signed-in user
    assert_equal @user.id, Event.last.user_id
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
    patch event_url(@event), params: {
      event: {
        title: "Updated title"
      }
    }

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
