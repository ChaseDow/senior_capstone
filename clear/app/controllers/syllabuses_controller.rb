# frozen_string_literal: true

class SyllabusesController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_syllabus, only: [ :show, :destroy, :create_course, :status ]

  def index
    @syllabuses = current_user.syllabuses.order(created_at: :desc)
  end

  def show; end

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

  # GET /syllabuses/:id/status
  #
  # Must render a turbo-frame wrapper that matches dom_id(@syllabus, :status)
  def status
    render :status, layout: false
  end

  # POST /syllabuses/:id/create_course
  def create_course
    if @syllabus.parse_status.in?(%w[queued processing])
      if turbo_frame_request?
        redirect_to status_syllabus_path(@syllabus), status: :see_other
        return
      end

      redirect_to syllabuses_path, notice: "Parsing already in progress."
      return
    end

    @syllabus.update!(parse_status: "queued", parse_error: nil)
    SyllabusParseJob.perform_later(@syllabus.id)

    if turbo_frame_request?
      redirect_to status_syllabus_path(@syllabus), status: :see_other
    else
      redirect_to syllabuses_path, notice: "Started parsing syllabus."
    end
  end


  def destroy
    @syllabus.destroy
    redirect_to syllabuses_path, notice: "Syllabus was successfully deleted."
  end

  private

  def set_syllabus
    @syllabus = current_user.syllabuses.find(params[:id])
  end

  def syllabus_params
    params.require(:syllabus).permit(:title, :file)
  end

  # Always render the wrapper view: app/views/syllabuses/status.html.erb
  def render_status_frame
    @syllabus.reload
    render :status, layout: false
  end
end
