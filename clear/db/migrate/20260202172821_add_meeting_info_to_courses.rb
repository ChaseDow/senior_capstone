class AddMeetingInfoToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :instructor, :string unless column_exists?(:courses, :instructor)

    # location already exists in your schema, so don't add it again
    # add_column :courses, :location, :string unless column_exists?(:courses, :location)

    add_column :courses, :starts_at, :time unless column_exists?(:courses, :starts_at)
    add_column :courses, :ends_at, :time unless column_exists?(:courses, :ends_at)

    add_column :courses, :start_date, :date unless column_exists?(:courses, :start_date)
    add_column :courses, :end_date, :date unless column_exists?(:courses, :end_date)

    add_column :courses, :meeting_days, :string, array: true, default: [], null: false unless column_exists?(:courses, :meeting_days)
  end
end
