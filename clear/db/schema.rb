# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_14_071111) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "courses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "end_date"
    t.time "end_time"
    t.string "location"
    t.string "meeting_days"
    t.string "professor"
    t.date "start_date"
    t.time "start_time"
    t.string "term"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "events", force: :cascade do |t|
    t.string "color", default: "#34D399", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at"
    t.string "location"
    t.boolean "recurring", default: false, null: false
    t.integer "repeat_days", default: [], null: false, array: true
    t.date "repeat_until"
    t.datetime "starts_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "repeat_until"], name: "index_events_on_user_id_and_repeat_until"
    t.index ["user_id", "starts_at"], name: "index_events_on_user_id_and_starts_at"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "schedule_blocks", force: :cascade do |t|
    t.string "category", default: "other", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.time "end_time", null: false
    t.string "location"
    t.boolean "locked", default: false, null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.bigint "schedule_id", null: false
    t.time "start_time", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["schedule_id", "day_of_week", "start_time"], name: "index_block_on_schedule_day_start"
    t.index ["schedule_id", "day_of_week"], name: "index_schedule_blocks_on_schedule_id_and_day_of_week"
    t.index ["schedule_id"], name: "index_schedule_blocks_on_schedule_id"
    t.check_constraint "day_of_week >= 0 AND day_of_week <= 6", name: "check_blocks_day_of_week"
    t.check_constraint "start_time < end_time", name: "check_blocks_start_before_end"
  end

  create_table "schedules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", default: "default", null: false
    t.string "timezone", default: "american/chicago", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "week_starts_on", default: 1, null: false
    t.index ["user_id", "name"], name: "index_schedules_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_schedules_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "events", "users"
  add_foreign_key "schedules", "users"
end
