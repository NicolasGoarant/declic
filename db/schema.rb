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

ActiveRecord::Schema[7.2].define(version: 2025_08_31_063343) do
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
    t.index ["slug"], name: "index_opportunities_on_slug", unique: true
    t.index ["source", "external_id"], name: "index_opportunities_on_source_and_external_id", unique: true
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
end
