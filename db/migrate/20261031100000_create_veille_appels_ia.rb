# Journal des appels à l'API Anthropic : un enregistrement par appel (réussi ou
# non), avec le modèle, la consommation et le coût estimé. Sert au plafond
# mensuel et à l'état de dépense (rake veille:cout).
class CreateVeilleAppelsIa < ActiveRecord::Migration[7.2]
  def change
    create_table :veille_appels_ia do |t|
      t.integer :candidate_id
      t.string  :passe,  null: false   # enrichissement | redaction
      t.string  :modele, null: false
      t.string  :statut, null: false   # ok | erreur_api | illisible | refuse_controle | plafond
      t.integer :input_tokens,  null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.decimal :cout_usd, precision: 10, scale: 6, null: false, default: 0
      t.integer :duree_ms
      t.text    :erreur
      t.timestamps
    end

    add_index :veille_appels_ia, :candidate_id
    add_index :veille_appels_ia, :created_at
    add_foreign_key :veille_appels_ia, :veille_candidates, column: :candidate_id, on_delete: :nullify
  end
end
