class ProjectsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_project, only: %i[ show edit update destroy ]

  # GET /projects or /projects.json
  def index
    @projects = current_user.projects.order(:title)
  end

  # GET /projects/1 or /projects/1.json
  def show
    @start_date =
      begin
        params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
      rescue ArgumentError
        Date.current
      end

    week_start  = @start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    @occurrences =
    @project.events
      .where("starts_at <= ?", range_end)
      .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
      .flat_map { |e| e.occurrences_between(range_start, range_end) }
      .sort_by(&:starts_at)
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects or /projects.json
  def create
    @project = Project.new(project_params)

    if @project.save
      @project.users << current_user
      respond_to do |format|
        format.html { redirect_to project_path(@project), notice: "Project created." }
        end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: "Project was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    @project.destroy!

    respond_to do |format|
      format.html { redirect_to projects_path, notice: "Project was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def agenda
    @date =
      begin
        params[:date].present? ? Date.parse(params[:date]) : Date.current
      rescue ArgumentError
        Date.current
      end

    range_start = @date.beginning_of_day
    range_end   = @date.end_of_day

    @occurrences = calendar_occurrences_for_range(range_start, range_end)

    now = Time.current
    next_occurrences = calendar_occurrences_for_range(now, now + 7.days)
    @next_occurrence = next_occurrences.find { |o| o.starts_at > now }

    render "dashboard/agenda"
  end

  def join
    project = Project.find_by(invite_token: params[:token])

    if project.nil?
      redirect_to root_path, alert: "Invalid invite link"
      return
    end

    unless project.users.include?(current_user)
      project.users << current_user
    end

    redirect_to project_path(project), notice: "You joined the project!"
  end

  private

    def occurrences_for_range(range_start, range_end)
      base_events = current_user.events

      non_recurring_events = base_events.where(recurring: false)
                                        .where(starts_at: range_start..range_end)

      recurring_events = base_events.where(recurring: true)
                                    .where("starts_at <= ?", range_end)
                                    .where("repeat_until >= ?", range_start.to_date)


      event_occurrences = (non_recurring_events + recurring_events).flat_map { |e| e.occurrences_between(range_start, range_end) }

      base_courses = current_user.courses
        .where("start_date <= ?", range_end.to_date)
        .where("end_date >= ?", range_start.to_date)
        .order(start_date: :asc)

      course_occurrences =
        base_courses.flat_map { |c| c.occurrences_between(range_start, range_end) }

      course_items =
        CourseItem
          .joins(:course)
          .where(courses: { user_id: current_user.id })
          .where(due_at: range_start..range_end)
          .includes(:course)

      (event_occurrences + course_occurrences + course_items.to_a)
        .sort_by(&:starts_at)
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = current_user.projects.find_by(id: params[:id])
      unless @project
        redirect_to projects_path, alert: "Project not found or you are not a member."
      end
    end

    # Only allow a list of trusted parameters through.
    def project_params
    params.require(:project).permit(
      :title,
      :description
    )
    end
end
