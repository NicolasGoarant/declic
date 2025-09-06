# app/helpers/application_helper.rb
module ApplicationHelper
  def safe_image_path(path, fallback: 'avatars/fallback.jpg')
    return asset_path(fallback) if path.blank?
    asset_path(path)
  rescue Sprockets::Rails::Helper::AssetNotFound
    asset_path(fallback)
  end
end
