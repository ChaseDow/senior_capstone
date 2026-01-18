class CoursesController < ApplicationController
  layout "app_shell"

  before_action :set_course, only: %i[show edit update destroy]

  def index
    @courses = current_user.courses.order(:title)
  end

  def show; end

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

  def edit; end

  def update
    if @course.update(course_params)
      redirect_to course_path(@course), notice: "Course updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @course.destroy
    redirect_to courses_path, notice: "Course deleted"
  end

  private

  def set_course
    @course = current_user.courses.find(params[:id])
  end

  def course_params
    params.require(:course).permit(
      :title,
      :term,
      :meeting_days,
      :start_date,
      :end_date,
      :start_time,
      :end_time,
      :professor,
      :location,
      :description
    )
  end
end
