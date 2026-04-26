class Api::SearchController < ApplicationController
  before_action :authenticate_user!

  def events
    results = current_user.events
                          .where("title ILIKE ?", "%#{sanitize_query}%")
                          .order(:title).limit(20)
    render json: results.map { |e| { id: e.id, label: e.title } }
  end

  def courses
    results = current_user.courses
                          .where("title ILIKE ?", "%#{sanitize_query}%")
                          .order(:title).limit(20)
    render json: results.map { |c| { id: c.id, label: c.title } }
  end

  def course_items
    results = CourseItem.joins(:course)
                        .where(courses: { user_id: current_user.id })
                        .where("course_items.title ILIKE ?", "%#{sanitize_query}%")
                        .order("course_items.title").limit(20)
    render json: results.map { |ci| { id: ci.id, label: ci.title } }
  end

  def work_shifts
    results = current_user.work_shifts
                          .where("title ILIKE ?", "%#{sanitize_query}%")
                          .order(:title).limit(20)
    render json: results.map { |ws| { id: ws.id, label: ws.title } }
  end

  private

  def sanitize_query
    params[:q].to_s.gsub(/[%_\\]/) { |c| "\\#{c}" }
  end
end
