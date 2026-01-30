# Frozen_string_literal: true

class SyllabusesController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_syllabus, only: [ :show, :destroy ]

  def index
    @syllabuses = current_user.syllabuses.order(created_at: :desc)
  end

  def show
  end

  def new
    @syllabus = current_user.syllabuses.new
  end

  def create
    @syllabus = current_user.syllabuses.new(syllabus_params)

    if @syllabus.save
      redirect_to @syllabus, notice: "Syllabus was successfully uploaded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @syllabus.destroy
    redirect_to syllabuses_url, notice: "Syllabus was successfully deleted."
  end

  private

  def set_syllabus
    @syllabus = current_user.syllabuses.find(params[:id])
  end

  def syllabus_params
    params.require(:syllabus).permit(:title, :file)
  end
end
