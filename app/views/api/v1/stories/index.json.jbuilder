# app/views/api/v1/stories/index.json.jbuilder
json.array! @stories do |story|
  json.extract! story, :id, :title, :location, :description, :latitude, :longitude, :slug, :chapo
  json.category 'histoires'
  json.image_url story.image_url if story.respond_to?(:image_url)
  json.happened_on story.happened_on&.iso8601 if story.respond_to?(:happened_on)
end
