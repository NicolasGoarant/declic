class AddVeilleCandidateToStories < ActiveRecord::Migration[7.2]
  def change
    # Trace le candidat dont la fiche est issue. Nullify plutôt que cascade :
    # supprimer un candidat ne doit jamais emporter une histoire publiée.
    add_reference :stories, :veille_candidate,
                  null:        true,
                  foreign_key: { to_table: :veille_candidates, on_delete: :nullify }
  end
end
