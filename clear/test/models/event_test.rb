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

  # duration fallback: derive_ends_at_from_duration

  test "sets ends_at from duration_minutes when ends_at is blank" do
    event = Event.new(
      title: "With duration",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      duration_minutes: 90,
      user: @user
    )

    event.valid?
    assert_equal event.starts_at + 90.minutes, event.ends_at
  end

  test "does not overwrite an explicit ends_at with duration_minutes" do
    starts_at = Time.zone.parse("2026-06-01 09:00:00")
    explicit_end = starts_at + 2.hours
    event = Event.new(
      title: "Explicit end",
      starts_at: starts_at,
      ends_at: explicit_end,
      duration_minutes: 30,
      user: @user
    )

    event.valid?
    assert_equal explicit_end, event.ends_at
  end

  test "leaves ends_at nil when duration_minutes is blank and ends_at is blank" do
    event = Event.new(
      title: "No end or duration",
      starts_at: Time.current,
      user: @user
    )

    event.valid?
    assert_nil event.ends_at
  end

  test "leaves ends_at nil when starts_at is blank" do
    event = Event.new(
      title: "No start",
      duration_minutes: 60,
      user: @user
    )

    event.valid?
    assert_nil event.ends_at
  end

  test "duration_minutes of zero sets ends_at equal to starts_at (valid via >= check)" do
    event = Event.new(
      title: "Zero duration",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      duration_minutes: 0,
      user: @user
    )

    event.valid?
    # 0.blank? is false, so the callback fires and sets ends_at = starts_at + 0
    # ends_at_after_starts_at uses >=, so equal times pass
    assert_equal event.starts_at, event.ends_at
    assert event.valid?
  end

  test "duration_minutes works for short durations like 15 minutes" do
    event = Event.new(
      title: "Quick meeting",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      duration_minutes: 15,
      user: @user
    )

    event.valid?
    assert_equal event.starts_at + 15.minutes, event.ends_at
  end

  test "duration_minutes works for long durations like 480 minutes (8 hours)" do
    event = Event.new(
      title: "All day workshop",
      starts_at: Time.zone.parse("2026-06-01 09:00:00"),
      duration_minutes: 480,
      user: @user
    )

    event.valid?
    assert_equal event.starts_at + 480.minutes, event.ends_at
  end

  # color validation

  test "accepts a valid hex color" do
    event = Event.new(title: "Colored", starts_at: Time.current, user: @user, color: "#FF5733")
    assert event.valid?, event.errors.full_messages.to_sentence
  end

  test "rejects a color that is not a valid hex format" do
    event = Event.new(title: "Bad color", starts_at: Time.current, user: @user, color: "not-a-color")
    assert_not event.valid?
    assert event.errors[:color].any?
  end

  test "rejects a hex color missing the leading hash" do
    event = Event.new(title: "No hash", starts_at: Time.current, user: @user, color: "FF5733")
    assert_not event.valid?
    assert event.errors[:color].any?
  end

  test "defaults color to #34D399 when nil is given" do
    event = Event.new(title: "Default color", starts_at: Time.current, user: @user, color: nil)
    event.valid?
    assert_equal "#34D399", event.color
    assert event.valid?, event.errors.full_messages.to_sentence
  end

  # recurrence validations

  test "recurring event is valid with repeat_days and repeat_until" do
    event = Event.new(
      title: "Weekly standup",
      starts_at: Time.zone.parse("2026-06-02 09:00:00"),
      user: @user,
      recurring: true,
      repeat_days: [ 1, 3, 5 ],
      repeat_until: Date.new(2026, 8, 29)
    )
    assert event.valid?, event.errors.full_messages.to_sentence
  end

  test "recurring event requires repeat_until" do
    event = Event.new(
      title: "No end",
      starts_at: Time.zone.parse("2026-06-02 09:00:00"),
      user: @user,
      recurring: true,
      repeat_days: [ 1 ],
      repeat_until: nil
    )
    assert_not event.valid?
    assert event.errors[:repeat_until].any?
  end

  test "recurring event requires at least one repeat_day" do
    event = Event.new(
      title: "No days",
      starts_at: Time.zone.parse("2026-06-02 09:00:00"),
      user: @user,
      recurring: true,
      repeat_days: [],
      repeat_until: Date.new(2026, 8, 29)
    )
    assert_not event.valid?
    assert event.errors[:repeat_days].any?
  end

  test "repeat_days rejects values outside 0-6" do
    event = Event.new(
      title: "Bad days",
      starts_at: Time.zone.parse("2026-06-02 09:00:00"),
      user: @user,
      recurring: true,
      repeat_days: [ 1, 7 ],
      repeat_until: Date.new(2026, 8, 29)
    )
    assert_not event.valid?
    assert event.errors[:repeat_days].any?
  end

  test "repeat_until must not be before the start date" do
    event = Event.new(
      title: "End before start",
      starts_at: Time.zone.parse("2026-06-02 09:00:00"),
      user: @user,
      recurring: true,
      repeat_days: [ 1 ],
      repeat_until: Date.new(2026, 5, 1)
    )
    assert_not event.valid?
    assert event.errors[:repeat_until].any?
  end

  test "repeat_until on same date as start is valid" do
    starts_at = Time.zone.parse("2026-06-02 09:00:00")
    event = Event.new(
      title: "Same day end",
      starts_at: starts_at,
      user: @user,
      recurring: true,
      repeat_days: [ starts_at.wday ],
      repeat_until: starts_at.to_date
    )
    assert event.valid?, event.errors.full_messages.to_sentence
  end

  test "non-recurring event does not require repeat_days or repeat_until" do
    event = Event.new(
      title: "One-off",
      starts_at: Time.current,
      user: @user,
      recurring: false
    )
    assert event.valid?, event.errors.full_messages.to_sentence
  end
end
