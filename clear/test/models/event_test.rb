require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "is valid with title and starts_at" do
    event = Event.new(
      title: "Study group",
      starts_at: Time.current
    )

    assert event.valid?
  end

  test "requires a title" do
    event = Event.new(starts_at: Time.current)

    assert_not event.valid?
    assert event.errors[:title].any?
  end

  test "requires starts_at" do
    event = Event.new(title: "No start time")

    assert_not event.valid?
    assert event.errors[:starts_at].any?
  end

  test "allows ends_at to be blank" do
    event = Event.new(title: "No end time", starts_at: Time.current, ends_at: nil)

    assert event.valid?
  end

  test "ends_at must be after starts_at when present" do
    starts_at = Time.current
    event = Event.new(
      title: "Bad times",
      starts_at: starts_at,
      ends_at: starts_at - 1.hour
    )

    assert_not event.valid?
    assert event.errors[:ends_at].any?
  end
end
