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

ActiveRecord::Schema[8.1].define(version: 2026_05_30_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", default: "", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "collection_documents", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id", "document_id"], name: "index_collection_documents_on_collection_id_and_document_id", unique: true
    t.index ["collection_id", "position"], name: "index_collection_documents_on_collection_id_and_position"
    t.index ["collection_id"], name: "index_collection_documents_on_collection_id"
    t.index ["document_id"], name: "index_collection_documents_on_document_id"
  end

  create_table "collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", default: "", null: false
    t.string "public_token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["public_token"], name: "index_collections_on_public_token", unique: true
    t.index ["user_id", "updated_at"], name: "index_collections_on_user_id_and_updated_at", order: { updated_at: :desc }
    t.index ["user_id"], name: "index_collections_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.text "body", default: "", null: false
    t.datetime "created_at", null: false
    t.boolean "is_public", default: false, null: false
    t.boolean "pinned", default: false, null: false
    t.string "public_token", null: false
    t.string "tags", default: [], null: false, array: true
    t.string "title", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["public_token"], name: "index_documents_on_public_token", unique: true
    t.index ["tags"], name: "index_documents_on_tags", using: :gin
    t.index ["user_id", "created_at"], name: "index_documents_on_user_id_and_created_at", order: { created_at: :desc }
    t.index ["user_id", "updated_at"], name: "index_documents_on_user_id_and_updated_at", order: { updated_at: :desc }
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "task_checklist_items", force: :cascade do |t|
    t.string "content", default: "", null: false
    t.datetime "created_at", null: false
    t.boolean "done", default: false, null: false
    t.integer "position", default: 0, null: false
    t.string "public_token", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["public_token"], name: "index_task_checklist_items_on_public_token", unique: true
    t.index ["task_id", "position"], name: "index_task_checklist_items_on_task_id_and_position"
    t.index ["task_id"], name: "index_task_checklist_items_on_task_id"
  end

  create_table "task_comments", force: :cascade do |t|
    t.string "author_kind", default: "human", null: false
    t.string "author_name"
    t.text "body", default: "", null: false
    t.datetime "created_at", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id", "created_at"], name: "index_task_comments_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_task_comments_on_task_id"
  end

  create_table "task_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_task_documents_on_document_id"
    t.index ["task_id", "document_id"], name: "index_task_documents_on_task_id_and_document_id", unique: true
    t.index ["task_id"], name: "index_task_documents_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.integer "position", default: 0, null: false
    t.string "public_token", null: false
    t.string "status", default: "todo", null: false
    t.string "title", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["public_token"], name: "index_tasks_on_public_token", unique: true
    t.index ["user_id", "status", "position"], name: "index_tasks_on_user_id_and_status_and_position"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "api_tokens", "users"
  add_foreign_key "collection_documents", "collections"
  add_foreign_key "collection_documents", "documents"
  add_foreign_key "collections", "users"
  add_foreign_key "documents", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "task_checklist_items", "tasks"
  add_foreign_key "task_comments", "tasks"
  add_foreign_key "task_documents", "documents"
  add_foreign_key "task_documents", "tasks"
  add_foreign_key "tasks", "users"
end
