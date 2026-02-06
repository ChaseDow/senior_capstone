require "test_helper"

class EventTest < ActiveSupport::TestCase
  fixtures :users

  setup do
    @user = users(:one)
    @starts_at = Time.zone.local(2026, 1, 1, 10, 0, 0)
  end

  test "is valid with title and starts_at" do
    event = build_event(title: "Study group", starts_at: @starts_at)
    assert event.valid?
  end

  test "requires a title" do
    event = build_event(title: nil, starts_at: @starts_at)
    assert_not event.valid?
    assert event.errors[:title].any?
  end

  test "requires starts_at" do
    event = build_event(title: "No start time", starts_at: nil)
    assert_not event.valid?
    assert event.errors[:starts_at].any?
  end

  test "allows ends_at to be blank" do
    event = build_event(title: "No end time", starts_at: @starts_at, ends_at: nil)
    assert event.valid?
  end

  test "ends_at must be after starts_at when present" do
    event = build_event(title: "Bad times", starts_at: @starts_at, ends_at: @starts_at - 1.hour)
    assert_not event.valid?
    assert event.errors[:ends_at].any?
  end

  private

  def build_event(attrs = {})
    Event.new({ user: @user, title: "Default", starts_at: @starts_at }.merge(attrs))
  end
end
