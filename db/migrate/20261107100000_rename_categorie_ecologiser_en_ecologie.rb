# frozen_string_literal: true

# La catégorie « ecologiser » devient « ecologie » (libellé « Écologie »). Les colonnes sont des
# chaînes (pas d'enum Rails) : on réécrit la valeur stockée. SQL direct, sans modèle, pour ne pas
# dépendre des validations du code courant. Idempotente : relancée, elle ne trouve plus rien à changer.
#
# Les Belles Histoires (stories) n'ont pas de colonne catégorie ; leurs `tags` libres ne portaient
# pas cette valeur en prod (0 ligne le 07/11/2026), on les laisse.
class RenameCategorieEcologiserEnEcologie < ActiveRecord::Migration[7.2]
  ANCIENNE = "ecologiser"
  NOUVELLE = "ecologie"
  COLONNES = { "opportunities" => "category", "veille_candidates" => "declic_category" }.freeze

  def up = renommer(ANCIENNE, NOUVELLE)

  def down = renommer(NOUVELLE, ANCIENNE)

  private

  def renommer(de, vers)
    COLONNES.each do |table, colonne|
      lignes = exec_update(<<~SQL.squish, "Renommage catégorie", [])
        UPDATE #{quote_table_name(table)} SET #{quote_column_name(colonne)} = #{quote(vers)}
        WHERE #{quote_column_name(colonne)} = #{quote(de)}
      SQL
      say "#{table}.#{colonne} : #{lignes} ligne(s) « #{de} » → « #{vers} »"
    end
  end
end
