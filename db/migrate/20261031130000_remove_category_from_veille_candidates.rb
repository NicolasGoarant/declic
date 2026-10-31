# « category » (belle_histoire / autre) était posée par Veille::Qualifier, retiré. Le type d'un
# élément est item_type (opportunite / belle_histoire), posé par Veille::AiEnricher.
class RemoveCategoryFromVeilleCandidates < ActiveRecord::Migration[7.2]
  def change
    remove_column :veille_candidates, :category, :string
  end
end
