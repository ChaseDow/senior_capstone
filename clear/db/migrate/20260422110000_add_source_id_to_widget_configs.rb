class AddSourceIdToWidgetConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :widget_configs, :source_id, :bigint
  end
end
