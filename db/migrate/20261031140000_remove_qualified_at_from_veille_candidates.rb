# « qualified_at » était posé par Veille::Qualifier (retiré) puis par AiEnricher ; plus aucun
# appelant. L'état d'un élément se lit dans enriched_at.
class RemoveQualifiedAtFromVeilleCandidates < ActiveRecord::Migration[7.2]
  def change
    remove_column :veille_candidates, :qualified_at, :datetime
  end
end
