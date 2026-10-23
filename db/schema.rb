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

ActiveRecord::Schema[8.1].define(version: 2026_10_23_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activity_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "level", null: false
    t.string "activity_key", null: false
    t.integer "kind", null: false
    t.integer "target_seconds"
    t.integer "actual_seconds", default: 0, null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at", null: false
    t.boolean "completed_fully", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "activity_key", "completed_at"], name: "idx_on_user_id_activity_key_completed_at_b38c9a0375"
    t.index ["user_id", "completed_at"], name: "index_activity_logs_on_user_id_and_completed_at"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "routine_logs", force: :cascade do |t|
    t.bigint "routine_id", null: false
    t.date "recorded_on", null: false
    t.boolean "achieved", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "completed_fully", default: true, null: false
    t.index ["routine_id", "recorded_on"], name: "index_routine_logs_on_routine_id_and_recorded_on", unique: true
    t.index ["routine_id"], name: "index_routine_logs_on_routine_id"
  end

  create_table "routines", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "category", null: false
    t.integer "current_level", default: 1, null: false
    t.date "last_recorded_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "category"], name: "index_routines_on_user_id_and_category", unique: true
    t.index ["user_id"], name: "index_routines_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "level", default: 1, null: false
    t.integer "rest_tickets", default: 2, null: false
    t.date "rest_tickets_refilled_on"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "visions", force: :cascade do |t|
    t.string "title"
    t.bigint "user_id", null: false
    t.text "content"
    t.date "target_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "achieved_at"
    t.boolean "top_priority", default: false, null: false
    t.index ["user_id"], name: "index_visions_on_user_id"
  end

  create_table "weekly_reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "week_start", null: false
    t.integer "clear_days", null: false
    t.string "outcome", null: false
    t.integer "level_before", null: false
    t.integer "level_after", null: false
    t.datetime "acknowledged_at"
    t.datetime "responded_at"
    t.boolean "accepted"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "week_start"], name: "index_weekly_reviews_on_user_id_and_week_start", unique: true
    t.index ["user_id"], name: "index_weekly_reviews_on_user_id"
  end

  add_foreign_key "activity_logs", "users"
  add_foreign_key "routine_logs", "routines"
  add_foreign_key "routines", "users"
  add_foreign_key "visions", "users"
  add_foreign_key "weekly_reviews", "users"
end
