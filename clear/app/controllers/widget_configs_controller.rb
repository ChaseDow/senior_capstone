class WidgetConfigsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_config, only: [:update, :destroy]

  # POST /widget_configs  (JSON)
  def create
    config = current_user.widget_configs.build(widget_config_params)
    if config.save
      render json: config.as_widget_json, status: :created
    else
      render json: { errors: config.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /widget_configs/:id  (JSON)
  # Used to persist GridStack positions after drag/resize, and to update config.
  def update
    if @config.update(widget_config_params)
      render json: { ok: true }
    else
      render json: { errors: @config.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /widget_configs/:id  (JSON)
  def destroy
    @config.destroy
    head :no_content
  end

  private

  def set_config
    @config = current_user.widget_configs.find(params[:id])
  end

  def widget_config_params
    params.require(:widget_config).permit(
      :widget_type, :title, :source_type, :source_id, :metric, :period, :goal,
      :gs_x, :gs_y, :gs_w, :gs_h
    )
  end
end
