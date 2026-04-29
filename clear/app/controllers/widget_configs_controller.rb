# frozen_string_literal: true

class WidgetConfigsController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!
  before_action :load_trackable_events, only: %i[new configure create]
  before_action :set_widget_config,     only: %i[update destroy]

  def new
    @widget_config = current_user.widget_configs.build
  end

  def picker
    render partial: "widget_configs/picker"
  end

  def configure
    @widget_type = params[:widget_type].to_s
    unless WidgetConfig::WIDGET_TYPE_KEYS.include?(@widget_type)
      head :not_found and return
    end

    @widget_config = current_user.widget_configs.build(
      widget_type: @widget_type,
      title: default_title_for(@widget_type)
    )
    render partial: "widget_configs/configure_#{@widget_type}"
  end

  def create
    @widget_config = current_user.widget_configs.build(widget_config_params)
    place_at_bottom(@widget_config)

    if @widget_config.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("personal_widgets_grid",
                                partial: "widget_configs/grid_item",
                                locals: { widget: @widget_config }),
            turbo_stream.update("widget_modal", "")
          ]
        end
        format.html { redirect_to analytics_personal_path }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "widget_modal",
            partial: "widget_configs/configure_#{@widget_config.widget_type}",
            locals: { widget_config: @widget_config }
          ), status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    @widget_config.update(widget_config_params)
    head :ok
  end

  def destroy
    @widget_config.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(view_context.dom_id(@widget_config))
      end
      format.html { redirect_to analytics_personal_path }
    end
  end

  def reorder
    positions = Array(params[:positions])
    WidgetConfig.transaction do
      positions.each_with_index do |item, idx|
        wc = current_user.widget_configs.find_by(id: item[:id] || item["id"])
        next unless wc

        wc.update!(
          grid_x: item[:x] || item["x"] || wc.grid_x,
          grid_y: item[:y] || item["y"] || wc.grid_y,
          grid_w: item[:w] || item["w"] || wc.grid_w,
          grid_h: item[:h] || item["h"] || wc.grid_h,
          position: idx
        )
      end
    end
    head :ok
  end

  private

  def set_widget_config
    @widget_config = current_user.widget_configs.find(params[:id])
  end

  def load_trackable_events
    @trackable_events = current_user.events.trackable.order(:title)
  end

  def widget_config_params
    permitted = params.require(:widget_config).permit(
      :widget_type, :title,
      :grid_x, :grid_y, :grid_w, :grid_h, :grid_min_w, :grid_min_h,
      config: [ :date_range, :goal, :unit, :stat_metric, :color, { event_ids: [] } ]
    )

    if permitted[:config].is_a?(ActionController::Parameters)
      permitted[:config] = permitted[:config].to_h.tap do |c|
        c["event_ids"] = Array(c["event_ids"]).reject(&:blank?).map(&:to_i)
      end
    end

    permitted
  end

  def place_at_bottom(wc)
    return if wc.grid_y.to_i.positive?
    max_y = current_user.widget_configs.maximum("grid_y + grid_h").to_i
    wc.grid_y = max_y
  end

  def default_title_for(widget_type)
    WidgetConfig::WIDGET_TYPES.find { |t| t[:key] == widget_type }&.dig(:label).to_s
  end
end
