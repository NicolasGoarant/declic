# Veille automatique : ce que les connecteurs récoltent (origine, texte brut,
# date de collecte) et ce que l'enrichissement IA propose (type, catégorie,
# commune, date ou régime, résumé reformulé).
class AddVeilleAutoToVeilleCandidates < ActiveRecord::Migration[7.2]
  def change
    change_table :veille_candidates do |t|
      t.string   :origin                     # jeveuxaider, agenda_nancy, formation, transentreprise, gazette, presse, import_xlsx
      t.string   :item_type                  # opportunite | belle_histoire (règle éditoriale)
      t.string   :declic_category            # clés Opportunity::CATEGORIES
      t.string   :commune
      t.date     :starts_on
      t.date     :ends_on
      t.string   :schedule_text              # régime sans date : « Ouvert toute l'année »
      t.text     :summary                    # résumé reformulé, 2 phrases
      t.text     :draft_body                 # brouillon StoryDrafter (belles histoires)
      t.string   :reliability                # haute | moyenne | basse
      t.string   :normalized_title
      t.string   :discard_reason             # pourquoi l'élément a été écarté automatiquement
      t.datetime :fetched_at
      t.datetime :enriched_at
      t.integer  :opportunity_id
    end

    add_index :veille_candidates, :origin
    add_index :veille_candidates, %i[normalized_title starts_on]
    add_foreign_key :veille_candidates, :opportunities, on_delete: :nullify
  end
end
