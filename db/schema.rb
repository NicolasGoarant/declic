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

ActiveRecord::Schema[7.2].define(version: 2025_12_01_142647) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "opportunities", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "category"
    t.string "organization"
    t.string "location"
    t.string "contact_email"
    t.string "contact_phone"
    t.string "tags"
    t.string "effort_level"
    t.string "time_commitment"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.string "source"
    t.string "source_url"
    t.string "external_id"
    t.string "address"
    t.string "city"
    t.string "postcode"
    t.string "website"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "published_at"
    t.datetime "expires_at"
    t.text "raw_payload"
    t.string "audience_level"
    t.string "career_outcome"
    t.text "skills"
    t.string "credential"
    t.boolean "mentorship", default: false, null: false
    t.boolean "alumni_network", default: false, null: false
    t.boolean "hiring_partners", default: false, null: false
    t.string "format"
    t.string "schedule"
    t.integer "duration_weeks"
    t.datetime "application_deadline"
    t.string "selectivity_level"
    t.text "prerequisites"
    t.decimal "cost_eur", precision: 10, scale: 2
    t.boolean "is_free", default: false, null: false
    t.boolean "scholarship_available", default: false, null: false
    t.text "funding_options"
    t.text "accessibility"
    t.text "impact_domains"
    t.text "impact_metric_hint"
    t.string "schedule_text"
    t.string "external_url"
    t.text "summary"
    t.string "intensity"
    t.string "mode"
    t.string "timezone"
    t.string "venue_name"
    t.string "organizer_name"
    t.string "url"
    t.string "image_url"
    t.index ["city"], name: "index_opportunities_on_city"
    t.index ["ends_at"], name: "index_opportunities_on_ends_at"
    t.index ["slug"], name: "index_opportunities_on_slug", unique: true
    t.index ["source", "external_id"], name: "index_opportunities_on_source_and_external_id", unique: true
    t.index ["starts_at"], name: "index_opportunities_on_starts_at"
    t.index ["url"], name: "index_opportunities_on_url", unique: true
  end

  create_table "raw_ingestions", force: :cascade do |t|
    t.integer "source_id", null: false
    t.string "external_id"
    t.json "payload"
    t.datetime "ingested_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id", "external_id"], name: "index_raw_ingestions_on_source_id_and_external_id", unique: true
    t.index ["source_id"], name: "index_raw_ingestions_on_source_id"
  end

  create_table "sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", null: false
    t.text "url", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "last_run_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true
    t.datetime "last_fetched_at"
    t.float "success_rate"
    t.index ["kind", "enabled"], name: "index_sources_on_kind_and_enabled"
    t.index ["url"], name: "index_sources_on_url", unique: true
  end

  create_table "stories", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.text "chapo"
    t.text "body"
    t.text "description"
    t.string "image_url"
    t.string "source_url"
    t.string "source_name"
    t.string "location"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_active"
    t.text "quote"
  end

  create_table "testimonials", force: :cascade do |t|
    t.string "name"
    t.integer "age"
    t.string "role"
    t.text "story"
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "raw_ingestions", "sources"
end
