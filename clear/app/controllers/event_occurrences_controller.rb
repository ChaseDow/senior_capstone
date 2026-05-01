# frozen_string_literal: true

class EventOccurrencesController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_occurrence, only: %i[update destroy]

  def create
    @occurrence = current_user.event_occurrences.find_or_initialize_by(
      event_id: occurrence_params[:event_id],
      occurred_on: occurrence_params[:occurred_on]
    )
    @occurrence.assign_attributes(occurrence_params)

    if @occurrence.save
      head :ok
    else
      render json: { errors: @occurrence.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @occurrence.update(occurrence_params)
      head :ok
    else
      render json: { errors: @occurrence.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @occurrence.destroy
    head :ok
  end

  private

  def set_occurrence
    @occurrence = current_user.event_occurrences.find(params[:id])
  end

  def occurrence_params
    params.require(:event_occurrence).permit(:event_id, :occurred_on, :completed, :duration_minutes, :notes)
  end
end
