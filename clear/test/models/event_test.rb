require "test_helper"

class EventTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "is valid with title and starts_at" do
    event = Event.new(
      title: "Study group",
      starts_at: Time.current,
      user: users(:one)
    )

    assert event.valid?
  end

  test "requires a title" do
    event = Event.new(starts_at: Time.current, user: users(:one))
    assert_not event.valid?
  end

  test "requires starts_at" do
    event = Event.new(title: "No start time", user: users(:one))
    assert_not event.valid?
  end

  test "allows ends_at to be blank" do
    event = Event.new(
      title: "No end time",
      starts_at: Time.current,
      ends_at: nil,
      user: @user
    )

    assert event.valid?, event.errors.full_messages.to_sentence
  end

  test "ends_at must be after starts_at when present" do
    starts_at = Time.current
    event = Event.new(
      title: "Bad times",
      starts_at: starts_at,
      ends_at: starts_at - 1.hour,
      user: @user
    )

    assert_not event.valid?
    assert event.errors[:ends_at].any?
  end
end
