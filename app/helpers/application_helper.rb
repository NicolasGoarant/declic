module ApplicationHelper
  def asset_exists?(logical_path)
    if Rails.application.config.assets.compile
      !!Rails.application.assets&.find_asset(logical_path)
    else
      Rails.application.assets_manifest.assets.key?(logical_path)
    end
  end
end
