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

ActiveRecord::Schema[8.1].define(version: 2026_02_02_223829) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "courses", force: :cascade do |t|
<<<<<<< HEAD
    t.string "color", default: "#34D399", null: false
=======
    t.string "code"
>>>>>>> 5e09732 (Setting up parsing for syllabuses)
    t.datetime "created_at", null: false
    t.text "description"
    t.date "end_date"
    t.time "end_time"
    t.time "ends_at"
    t.string "instructor"
    t.string "location"
    t.string "meeting_days"
    t.string "professor"
    t.boolean "recurring", default: false, null: false
    t.integer "repeat_days", default: [], null: false, array: true
    t.date "repeat_until"
    t.date "start_date"
    t.time "start_time"
    t.time "starts_at"
    t.string "term"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "repeat_until"], name: "index_courses_on_user_id_and_repeat_until"
    t.index ["user_id", "start_date"], name: "index_courses_on_user_id_and_start_date"
    t.index ["user_id"], name: "index_courses_on_user_id"
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

  create_table "syllabuses", force: :cascade do |t|
    t.jsonb "course_draft"
    t.bigint "course_id"
    t.datetime "created_at", null: false
    t.text "parse_error"
    t.string "parse_status"
    t.datetime "parsed_at"
    t.text "parsed_text"
    t.string "title", null: false
    t.bigint "user_id", null: false
    t.index ["course_id"], name: "index_syllabuses_on_course_id"
    t.index ["user_id"], name: "index_syllabuses_on_user_id"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "courses", "users"
  add_foreign_key "events", "users"
  add_foreign_key "schedules", "users"
  add_foreign_key "syllabuses", "courses", on_delete: :nullify
  add_foreign_key "syllabuses", "users"
end
