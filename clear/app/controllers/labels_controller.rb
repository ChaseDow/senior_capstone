# frozen_string_literal: true

class LabelsController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :set_label, only: %i[edit update destroy]

  def index
    @labels = current_user.labels.order(:name)
  end


  def new
    @label = current_user.labels.new
    render layout: false if turbo_frame_request?
  end

  def create
    @label = current_user.labels.new(label_params)

    begin
      saved = @label.save
    rescue ActiveRecord::RecordNotUnique
      @label.errors.add(:name, "has already been taken")
      saved = false
    end

    if saved
      # Inline event form flow: replace the event frame
      if params[:turbo_frame].to_s == "event_label_area"
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "event_label_area",
              partial: "labels/event_label_area",
              locals: { labels: current_user.labels.order(:name), selected_id: @label.id }
            )
          end

          format.html { redirect_to labels_path, notice: "Label created." }
        end
      else
        # Labels page flow: just navigate back to index so they SEE it
        redirect_to labels_path, notice: "Label created."
      end
    else
      respond_to do |format|
        format.turbo_stream { render :new, formats: [ :html ], status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end







  def edit
    render layout: false if turbo_frame_request?
  end

  def update
    if @label.update(label_params)
      redirect_to labels_path, notice: "Label updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @label.destroy!
    redirect_to labels_path, notice: "Label deleted."
  end

  private

  def set_label
    @label = current_user.labels.find(params[:id])
  end

  def label_params
    params.require(:label).permit(:name, :color)
  end
end
