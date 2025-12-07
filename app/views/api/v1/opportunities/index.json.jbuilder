json.array! @opportunities do |opportunity|
  json.extract! opportunity, :id, :title, :category, :organization, :location, :description, :latitude, :longitude, :slug
  json.image_url opportunity.image_url
  json.starts_at opportunity.starts_at&.iso8601
end
