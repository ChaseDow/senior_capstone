# app/controllers/syllabuses_controller.rb
class SyllabusesController < ApplicationController
  layout "app_shell"
  before_action :set_syllabus, only: [:show, :destroy]

  # GET /syllabuses
  def index
    @syllabuses = Syllabus.all.order(created_at: :desc)
  end

  # GET /syllabuses/1
  def show
  end

  # GET /syllabuses/new
  def new
    @syllabus = Syllabus.new
  end

  # POST /syllabuses
  def create
    @syllabus = Syllabus.new(syllabus_params)

    if @syllabus.save
      redirect_to @syllabus, notice: 'Syllabus was successfully uploaded.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /syllabuses/1
  def destroy
    @syllabus.destroy
    redirect_to syllabuses_url, notice: 'Syllabus was successfully deleted.'
  end

  private
    def set_syllabus
      @syllabus = Syllabus.find(params[:id])
    end

    def syllabus_params
      params.require(:syllabus).permit(:title, :created_at, :file)
    end
end