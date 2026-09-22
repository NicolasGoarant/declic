class AddGeocodingFlaggedReason < ActiveRecord::Migration[7.2]
  def change
    # Rempli quand le garde-fou de distance (NancyGeocodable) a REJETÉ un
    # résultat de géocodage trop loin de Nancy : la ligne reste sans
    # coordonnées, et l'admin voit pourquoi au lieu de deviner.
    add_column :opportunities, :geocoding_flagged_reason, :string unless column_exists?(:opportunities, :geocoding_flagged_reason)
    add_column :stories, :geocoding_flagged_reason, :string unless column_exists?(:stories, :geocoding_flagged_reason)
  end
end
