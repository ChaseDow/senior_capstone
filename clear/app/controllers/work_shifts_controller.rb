# frozen_string_literal: true

class WorkShiftsController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_work_shift, only: %i[show edit update destroy]

  def index
    @q = params[:q].to_s.strip
    @work_shifts = current_user.work_shifts.ordered
    @work_shifts = @work_shifts.where("title ILIKE ? OR location ILIKE ? OR description ILIKE ?",
                                      "%#{@q}%", "%#{@q}%", "%#{@q}%") if @q.present?
  end

  def show
    return unless turbo_frame_request?

    render partial: "work_shifts/popover_detail",
           locals: { work_shift: @work_shift }
  end

  def new
    @work_shift = current_user.work_shifts.new(color: "#34D399")
  end

  def create
    @work_shift = current_user.work_shifts.new(work_shift_params)

    if @work_shift.save
      redirect_to work_shifts_path, notice: "Shift created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @work_shift.update(work_shift_params)
      redirect_to work_shifts_path, notice: "Shift updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @work_shift.destroy!
    redirect_to work_shifts_path, notice: "Shift deleted."
  end

  private

  def set_work_shift
    @work_shift = current_user.work_shifts.find(params[:id])
  end

  def work_shift_params
    params.require(:work_shift).permit(
      :title, :location, :start_time, :end_time, :start_date,
      :color, :description, :recurring, :repeat_until,
      repeat_days: []
    )
  end
end
