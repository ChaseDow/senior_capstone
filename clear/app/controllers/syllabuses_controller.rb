# frozen_string_literal: true

class SyllabusesController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_syllabus, only: %i[
    show destroy create_course status course_preview course_preview_frame confirm_course
  ]

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

  # POST /syllabuses/:id/create_course
  def create_course
    unless @syllabus.parse_status.in?(%w[queued processing])
      @syllabus.update!(parse_status: "queued", parse_error: nil, course_draft: {})
      SyllabusParseJob.perform_later(@syllabus.id)
    end

    redirect_to course_preview_syllabus_path(@syllabus), notice: "Parsing started…"
  end

# GET /syllabuses/:id/status
def status
  render :status, layout: false
end


  # GET /syllabuses/:id/course_preview
  def course_preview
    @draft  = normalized_draft_for_form(@syllabus.course_draft || {})
    @course = current_user.courses.new(remap_preview_attrs(@draft))
  end

  # GET /syllabuses/:id/course_preview_frame
  def course_preview_frame
    @draft  = normalized_draft_for_form(@syllabus.course_draft || {})
    @course = current_user.courses.new(@draft)

    render :course_preview_frame, layout: false
  end


  # POST /syllabuses/:id/confirm_course
  def confirm_course
    attrs = remap_form_attrs(course_params.to_h)

    @course = current_user.courses.new(attrs)

    if @course.save
      @syllabus.update!(course: @course)
      redirect_to course_path(@course), notice: "Course created."
    else
      @draft = normalized_draft_for_form(@syllabus.course_draft || {})
      render :course_preview, status: :unprocessable_entity
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

  def course_params
    params.require(:course).permit(
      :title, :code, :term,
      :professor, :instructor,
      :meeting_days, :location,
      :start_date, :end_date,
      :start_time, :end_time,
      :starts_at, :ends_at,
      :description
    )
  end

  def normalized_draft_for_form(draft)
    d = draft.deep_dup
    d["start_time"] = normalize_time_for_input(d["start_time"])
    d["end_time"]   = normalize_time_for_input(d["end_time"])
    d["starts_at"]  = normalize_time_for_input(d["starts_at"])
    d["ends_at"]    = normalize_time_for_input(d["ends_at"])
    d
  end

  def normalize_time_for_input(v)
    return nil if v.blank?
    v.to_s.split(":").first(2).join(":") # "08:00:00" -> "08:00"
  end

  def remap_preview_attrs(draft)
    cols = Course.column_names
    out = draft.deep_dup

    if cols.include?("start_time") && out["start_time"].blank? && out["starts_at"].present?
      out["start_time"] = out["starts_at"]
    end
    if cols.include?("end_time") && out["end_time"].blank? && out["ends_at"].present?
      out["end_time"] = out["ends_at"]
    end

    if cols.include?("instructor") && out["instructor"].blank? && out["professor"].present?
      out["instructor"] = out["professor"]
    end
    if cols.include?("professor") && out["professor"].blank? && out["instructor"].present?
      out["professor"] = out["instructor"]
    end

    out
  end

  def remap_form_attrs(attrs)
    cols = Course.column_names
    out = attrs.deep_dup

    if cols.include?("start_time") && out["start_time"].blank? && out["starts_at"].present?
      out["start_time"] = out.delete("starts_at")
    end
    if cols.include?("end_time") && out["end_time"].blank? && out["ends_at"].present?
      out["end_time"] = out.delete("ends_at")
    end

    out
  end
end
