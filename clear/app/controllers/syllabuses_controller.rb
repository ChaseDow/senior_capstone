# frozen_string_literal: true

class SyllabusesController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_syllabus, only: %i[
    show destroy create_course status course_preview course_preview_frame confirm_course
    course_items_preview confirm_course_items
  ]

  PREVIEW_FIELDS = %i[
    title code term professor meeting_days location office office_hours start_time end_time start_date end_date
  ].freeze

  def index
    redirect_to courses_path
  end

  def show; end

  def new
    @syllabus = current_user.syllabuses.new
  end

  def create
    @syllabus = current_user.syllabuses.new(syllabus_params)

    if @syllabus.save
      @syllabus.update!(parse_status: "queued", parse_error: nil, course_draft: {})
      begin
        SyllabusParseJob.perform_now(@syllabus.id)
        redirect_to course_preview_syllabus_path(@syllabus), notice: "Syllabus uploaded and parsed."
      rescue StandardError
        @syllabus.destroy
        redirect_to courses_path, alert: "Syllabus import failed. The upload was removed."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create_course
    if @syllabus.parse_status.in?(%w[queued processing])
      redirect_to course_preview_syllabus_path(@syllabus), notice: "Parsing in progress."
      return
    end

    @syllabus.update!(parse_status: "queued", parse_error: nil, course_draft: {})
    begin
      SyllabusParseJob.perform_now(@syllabus.id)
      redirect_to course_preview_syllabus_path(@syllabus), notice: "Parsing complete."
    rescue StandardError
      @syllabus.destroy
      redirect_to courses_path, alert: "Parsing failed. The upload was removed."
    end
  end

  def status
    render :status, layout: false
  end

  def course_preview
    @draft  = normalized_draft_for_form(@syllabus.course_draft || {})
    @course = current_user.courses.new(remap_preview_attrs(@draft))
    @missing_fields = missing_preview_fields(@course)
  end

  def course_preview_frame
    @draft  = normalized_draft_for_form(@syllabus.course_draft || {})
    @course = current_user.courses.new(remap_preview_attrs(@draft))
    @missing_fields = missing_preview_fields(@course)

    render :course_preview_frame, layout: false
  end

  def confirm_course
    attrs = remap_form_attrs(course_params.to_h)
    @course = current_user.courses.new(attrs)

    if @course.save
      @syllabus.update!(course: @course)
      redirect_to course_items_preview_syllabus_path(@syllabus),
                  notice: "Course created — review the items we found in your syllabus."
    else
      @draft = normalized_draft_for_form(@syllabus.course_draft || {})
      @missing_fields = missing_preview_fields(@course)
      render :course_preview, status: :unprocessable_entity
    end
  end

  def course_items_preview
    @course = @syllabus.course
    draft = @syllabus.course_draft || {}
    @draft_items = (draft["course_items"] || draft[:course_items] || []).map(&:with_indifferent_access)
    @valid_kinds = CourseItem.kinds.keys
  end

  def confirm_course_items
    @course = @syllabus.course

    unless @course
      redirect_to course_preview_syllabus_path(@syllabus), alert: "Create the course first."
      return
    end

    raw_items = params[:items]
    items = case raw_items
    when ActionController::Parameters then raw_items.values
    when Hash then raw_items.values
    else []
    end

    created = 0
    items.each do |raw|
      item = raw.is_a?(ActionController::Parameters) ? raw.permit(:title, :kind, :due_at, :details, :_remove) : raw
      next if item[:_remove] == "1"
      next if item[:title].blank?

      kind = item[:kind].to_s
      next unless kind.in?(CourseItem.kinds.keys)

      record = @course.course_items.new(
        title: item[:title],
        kind: kind,
        due_at: parse_draft_due_at(item[:due_at]),
        details: item[:details].presence
      )
      created += 1 if record.save
    end

    redirect_to course_course_items_path(@course), notice: "#{created} course item#{"s" unless created == 1} saved."
  end

  def destroy
    go_to_new_upload = params[:return_to] == "new" && @syllabus.course_id.blank?
    @syllabus.destroy
    if go_to_new_upload
      redirect_to new_syllabus_path, notice: "Syllabus deleted."
    else
      redirect_to courses_url, notice: "Syllabus was successfully deleted."
    end
  end

  private

  def set_syllabus
    @syllabus = current_user.syllabuses.find(params[:id])
  end

  def parse_draft_due_at(raw)
    return nil if raw.blank?
    Time.zone.parse(raw.to_s)
  rescue ArgumentError
    nil
  end

  def syllabus_params
    params.require(:syllabus).permit(:title, :file)
  end

  def course_params
    params.require(:course).permit(
      :title, :code, :term,
      :professor, :instructor,
      :meeting_days, :location,
      :office, :office_hours,
      :start_date, :end_date,
      :start_time, :end_time,
      :starts_at, :ends_at,
      :description,
      :color, :recurring, :repeat_until, repeat_days: []
    )
  end

  def missing_preview_fields(course)
    PREVIEW_FIELDS.select { |attr| course.public_send(attr).blank? }
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
    v.to_s.split(":").first(2).join(":")
  end

  def remap_preview_attrs(draft)
    cols = Course.column_names
    out = draft.deep_dup
    out.delete("course_items")
    out.delete(:course_items)

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
