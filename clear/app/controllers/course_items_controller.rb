# frozen_string_literal: true

class CourseItemsController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_course
  before_action :set_course_item, only: %i[edit update destroy]

  def index
    @course_items = @course.course_items.order(:due_at)
    @course_item  = @course.course_items.new
  end

  def create
    @course_item = @course.course_items.new(course_item_params)

    if @course_item.save
      respond_to do |format|
        format.html do
          redirect_to course_course_items_path(@course), notice: "Course item created."
        end

        format.turbo_stream do
          redirect_to course_course_items_path(@course),
                      notice: "Course item created.",
                      status: :see_other
        end
      end
    else
      @course_items = @course.course_items.order(:due_at)

      respond_to do |format|
        format.html { render :index, status: :unprocessable_entity }
        format.turbo_stream { render :index, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    if @course_item.update(course_item_params)
      respond_to do |format|
        format.html do
          redirect_to course_course_items_path(@course), notice: "Course item updated."
        end

        format.turbo_stream do
          redirect_to course_course_items_path(@course),
                      notice: "Course item updated.",
                      status: :see_other
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @course_item.destroy!

    respond_to do |format|
      format.html do
        redirect_to course_course_items_path(@course), notice: "Course item deleted."
      end

      format.turbo_stream do
        redirect_to course_course_items_path(@course),
                    notice: "Course item deleted.",
                    status: :see_other
      end
    end
  end

  private

  def set_course
    @course = current_user.courses.find(params[:course_id])
  end

  def set_course_item
    @course_item = @course.course_items.find(params[:id])
  end

  def course_item_params
    params.require(:course_item).permit(:title, :kind, :due_at, :details)
  end
end
