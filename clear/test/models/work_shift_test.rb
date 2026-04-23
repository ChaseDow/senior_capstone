require "test_helper"

class WorkShiftTest < ActiveSupport::TestCase
  def valid_shift_attrs(overrides = {})
    {
      title: "Barista shift",
      color: "#34D399",
      start_date: Date.new(2026, 6, 2),
      start_time: Time.zone.parse("09:00"),
      end_time: Time.zone.parse("17:00"),
      recurring: false,
      user: users(:one)
    }.merge(overrides)
  end

  # basic model validity

  test "is valid with all required fields (non-recurring)" do
    shift = WorkShift.new(valid_shift_attrs)
    assert shift.valid?, shift.errors.full_messages.to_sentence
  end

  test "is valid as a recurring shift with repeat_days and repeat_until" do
    shift = WorkShift.new(valid_shift_attrs(
      recurring: true,
      repeat_days: [ 1, 3, 5 ],
      repeat_until: Date.new(2026, 8, 29)
    ))
    assert shift.valid?, shift.errors.full_messages.to_sentence
  end

  # required field presence

  test "requires a title" do
    shift = WorkShift.new(valid_shift_attrs(title: nil))
    assert_not shift.valid?
    assert shift.errors[:title].any?
  end

  test "requires a color" do
    shift = WorkShift.new(valid_shift_attrs(color: nil))
    assert_not shift.valid?
    assert shift.errors[:color].any?
  end

  test "requires start_date" do
    shift = WorkShift.new(valid_shift_attrs(start_date: nil))
    assert_not shift.valid?
    assert shift.errors[:start_date].any?
  end

  test "requires start_time" do
    shift = WorkShift.new(valid_shift_attrs(start_time: nil))
    assert_not shift.valid?
    assert shift.errors[:start_time].any?
  end

  test "requires end_time" do
    shift = WorkShift.new(valid_shift_attrs(end_time: nil))
    assert_not shift.valid?
    assert shift.errors[:end_time].any?
  end

  # end_time / start_time ordering

  test "end_time must be after start_time" do
    shift = WorkShift.new(valid_shift_attrs(
      start_time: Time.zone.parse("17:00"),
      end_time: Time.zone.parse("09:00")
    ))
    assert_not shift.valid?
    assert shift.errors[:end_time].any?
  end

  test "end_time equal to start_time is invalid" do
    t = Time.zone.parse("09:00")
    shift = WorkShift.new(valid_shift_attrs(start_time: t, end_time: t))
    assert_not shift.valid?
    assert shift.errors[:end_time].any?
  end

  # repeat_until ordering

  test "repeat_until must be after start_date" do
    shift = WorkShift.new(valid_shift_attrs(
      start_date: Date.new(2026, 6, 2),
      repeat_until: Date.new(2026, 6, 1),
      recurring: true,
      repeat_days: [ 1 ]
    ))
    assert_not shift.valid?
    assert shift.errors[:repeat_until].any?
  end

  test "repeat_until equal to start_date is invalid" do
    d = Date.new(2026, 6, 2)
    shift = WorkShift.new(valid_shift_attrs(
      start_date: d,
      repeat_until: d,
      recurring: true,
      repeat_days: [ d.wday ]
    ))
    assert_not shift.valid?
    assert shift.errors[:repeat_until].any?
  end

  # recurrence: repeat_days

  test "recurring shift requires at least one repeat_day" do
    shift = WorkShift.new(valid_shift_attrs(
      recurring: true,
      repeat_days: [],
      repeat_until: Date.new(2026, 8, 29)
    ))
    assert_not shift.valid?
    assert shift.errors[:repeat_days].any?
  end

  test "repeat_days rejects values outside 0-6" do
    shift = WorkShift.new(valid_shift_attrs(
      recurring: true,
      repeat_days: [ 1, 7 ],
      repeat_until: Date.new(2026, 8, 29)
    ))
    assert_not shift.valid?
    assert shift.errors[:repeat_days].any?
  end

  test "repeat_days accepts all valid weekday values 0-6" do
    shift = WorkShift.new(valid_shift_attrs(
      recurring: true,
      repeat_days: [ 0, 1, 2, 3, 4, 5, 6 ],
      repeat_until: Date.new(2026, 8, 29)
    ))
    assert shift.valid?, shift.errors.full_messages.to_sentence
  end

  # non-recurring: recurrence fields cleared

  test "non-recurring shift clears repeat_days and repeat_until" do
    shift = WorkShift.new(valid_shift_attrs(
      recurring: false,
      repeat_days: [ 1, 3 ],
      repeat_until: Date.new(2026, 8, 29)
    ))
    shift.valid?
    assert_empty shift.repeat_days
    assert_nil shift.repeat_until
  end
end
