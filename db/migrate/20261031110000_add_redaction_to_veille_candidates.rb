# Suivi de la rédaction du récit d'une belle histoire (Veille::Redaction::Brouillon).
#   draft_status      aucun | redige | a_reprendre (erreur d'API, réessayable) | a_verifier (contrôle bloquant)
#   draft_manques     informations absentes de la source, signalées par le modèle
#   draft_controles   résultat de Veille::Redaction::Controles
#   draft_attempts    appels tentés par la veille automatique (3 au plus)
#   accord_obtenu_at  accord de la personne racontée
class AddRedactionToVeilleCandidates < ActiveRecord::Migration[7.2]
  def up
    change_table :veille_candidates do |t|
      t.string   :draft_status,   null: false, default: "aucun"
      t.json     :draft_manques
      t.json     :draft_controles
      t.integer  :draft_attempts, null: false, default: 0
      t.datetime :accord_obtenu_at
    end
    add_index :veille_candidates, :draft_status

    # Les brouillons déjà rédigés par l'ancien StoryDrafter.
    execute "UPDATE veille_candidates SET draft_status = 'redige' WHERE draft_body IS NOT NULL AND draft_body <> ''"
  end

  def down
    remove_index :veille_candidates, :draft_status
    change_table :veille_candidates do |t|
      t.remove :draft_status, :draft_manques, :draft_controles, :draft_attempts, :accord_obtenu_at
    end
  end
end
