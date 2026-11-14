# frozen_string_literal: true

class AddOrigineToVeilleAppelsIa < ActiveRecord::Migration[7.2]
  def change
    add_column :veille_appels_ia, :origine, :string, null: false, default: "veille"
  end
end
