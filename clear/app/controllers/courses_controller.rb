class CoursesController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_course, only: %i[show edit update destroy]

  def index
    @courses = current_user.courses.order(:title)
  end

  def show
    return unless turbo_frame_request?

    render partial: "courses/drawer_detail",
           locals: { course: @course, start_date: params[:start_date] }
  end

  def new
    @course = current_user.courses.new
  end

  def create
    @course = current_user.courses.new(course_params)

    if @course.save
      redirect_to course_path(@course), notice: "Course created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return unless turbo_frame_request?

    render partial: "courses/drawer_edit", locals: { course: @course, start_date: params[:start_date] }
  end

  def update
    if @course.update(course_params)
      respond_to do |format|
        format.html { redirect_to course_path(@course), notice: "Course updated. " }

        format.turbo_stream do
          unless turbo_frame_request?
            redirect_to course_path(@course), status: :see_other
            next
          end

          start_date = parse_start_date(params[:start_date])
          occurrences = dashboard_occurrences_for(start_date)

          render turbo_stream: [
            turbo_stream.replace(
              "dashboard_calendar",
              partial: "dashboard/calendar_frame",
              locals: { events: occurrences, start_date: start_date }
            ),
            turbo_stream.update("event_drawer", "")
          ]
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "course_drawer",
            partial: "courses/drawer_edit",
            locals: { course: @course, start_date: params[:start_date] }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @course.destroy!

    respond_to do |format|
      format.html { redirect_to courses_path, notice: "Course deleted." }

      format.turbo_stream do
        unless turbo_frame_request?
          redirect_to courses_path, status: :see_other
          next
        end

        start_date = parse_start_date(params[:start_date])
        occurrences = dashboard_occurrences_for(start_date)

        render turbo_stream: [
          turbo_stream.replace(
            "dashboard_calendar",
            partial: "dashboard/calendar_frame",
            locals: { events: occurrences, start_date: start_date }
          ),
          turbo_stream.update("event_drawer", "")
        ]
      end
    end
  end

  private

  def set_course
    @course = current_user.courses.find(params[:id])
  end

  def parse_start_date(raw)
    raw.present? ? Date.parse(raw) : Date.current
  rescue ArgumentError
    Date.current
  end

  def dashboard_occurrences_for(start_date)
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    base_courses =
      current_user.courses
        .where("start_date <= ?", range_end)
        .where("end_date >= ?", range_start.to_date)
        .order(start_date: :asc)

    base_courses.flat_map { |c| c.occurrences_between(range_start, range_end) }
              .sort_by(&:starts_at)
  end

  def course_params
    params.require(:course).permit(
      :title,
      :term,
      :color,
      :start_date,
      :end_date,
      :start_time,
      :end_time,
      :professor,
      :location,
      :description,
      repeat_days: []
    )
  end
end
