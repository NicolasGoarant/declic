json.array! @stories do |story|
  json.extract! story, :id, :title, :chapo, :location, :latitude, :longitude, :slug
  json.image_url story.image_url
  json.happened_on story.happened_on&.iso8601
end
