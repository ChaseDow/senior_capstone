require "test_helper"

class CourseTest < ActiveSupport::TestCase
  def valid_course_attrs(overrides = {})
    {
      title: "Intro to CS",
      start_date: Date.today,
      end_date: Date.today + 16.weeks,
      start_time: Time.zone.parse("09:00"),
      meeting_days: "MWF",
      user: users(:one)
    }.merge(overrides)
  end

  # duration fallback: derive_end_time_from_duration

  test "sets end_time from duration_minutes when end_time is blank" do
    course = Course.new(valid_course_attrs(start_time: Time.zone.parse("09:00"), duration_minutes: 75))

    course.valid?
    # Compare against course.start_time after Rails casts the time column (base date 2000-01-01)
    assert_equal course.start_time + 75.minutes, course.end_time
  end

  test "does not overwrite an explicit end_time with duration_minutes" do
    # Use the Rails base date (2000-01-01) so times round-trip through the time column cleanly
    explicit_end = Time.zone.parse("2000-01-01 10:30:00")
    course = Course.new(valid_course_attrs(
      start_time: Time.zone.parse("09:00"),
      end_time: explicit_end,
      duration_minutes: 30
    ))

    course.valid?
    assert_equal course.end_time.hour, 10
    assert_equal course.end_time.min, 30
  end

  test "leaves end_time nil when both end_time and duration_minutes are blank" do
    course = Course.new(valid_course_attrs)

    course.valid?
    assert_nil course.end_time
  end

  test "leaves end_time nil when start_time is blank" do
    course = Course.new(valid_course_attrs(start_time: nil, duration_minutes: 60))

    course.valid?
    assert_nil course.end_time
  end

  test "duration_minutes works for a standard 50-minute class" do
    course = Course.new(valid_course_attrs(start_time: Time.zone.parse("14:00"), duration_minutes: 50))

    course.valid?
    assert_equal course.start_time + 50.minutes, course.end_time
  end

  test "duration_minutes works for a 3-hour lab (180 minutes)" do
    course = Course.new(valid_course_attrs(start_time: Time.zone.parse("13:00"), duration_minutes: 180))

    course.valid?
    assert_equal course.start_time + 180.minutes, course.end_time
  end

  test "duration_minutes of zero sets end_time equal to start_time (valid via >= check)" do
    course = Course.new(valid_course_attrs(start_time: Time.zone.parse("09:00"), duration_minutes: 0))

    course.valid?
    # 0.blank? is false, so callback fires; end_time_after_start_time uses >=, so equal times pass
    assert_equal course.start_time, course.end_time
    assert course.valid?, course.errors.full_messages.to_sentence
  end

  # basic model validity

  test "is valid with required fields and meeting_days" do
    course = Course.new(valid_course_attrs)
    assert course.valid?, course.errors.full_messages.to_sentence
  end

  test "requires a title" do
    course = Course.new(valid_course_attrs(title: nil))
    assert_not course.valid?
    assert course.errors[:title].any?
  end

  test "requires start_date" do
    course = Course.new(valid_course_attrs(start_date: nil))
    assert_not course.valid?
  end

  test "requires end_date" do
    course = Course.new(valid_course_attrs(end_date: nil))
    assert_not course.valid?
  end

  test "end_date must not be before start_date" do
    course = Course.new(valid_course_attrs(
      start_date: Date.today,
      end_date: Date.today - 1.day
    ))
    assert_not course.valid?
    assert course.errors[:end_date].any?
  end

  test "end_time must be after start_time when both present" do
    start_time = Time.zone.parse("10:00")
    course = Course.new(valid_course_attrs(
      start_time: start_time,
      end_time: start_time - 1.hour
    ))
    assert_not course.valid?
    assert course.errors[:end_time].any?
  end
end
