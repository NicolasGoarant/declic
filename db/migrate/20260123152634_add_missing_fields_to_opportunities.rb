class AddMissingFieldsToOpportunities < ActiveRecord::Migration[7.0]
  def change
    # Textes et Dates
    add_column :opportunities, :quote, :text unless column_exists?(:opportunities, :quote)
    add_column :opportunities, :quote_author, :string unless column_exists?(:opportunities, :quote_author)
    add_column :opportunities, :start_date, :string unless column_exists?(:opportunities, :start_date)
    add_column :opportunities, :end_date, :string unless column_exists?(:opportunities, :end_date)
    add_column :opportunities, :time_commitment, :string unless column_exists?(:opportunities, :time_commitment)
    add_column :opportunities, :challenges, :text unless column_exists?(:opportunities, :challenges)

    # Légendes photos (L'erreur actuelle vient d'ici)
    add_column :opportunities, :inline_caption_1, :string unless column_exists?(:opportunities, :inline_caption_1)
    add_column :opportunities, :inline_caption_2, :string unless column_exists?(:opportunities, :inline_caption_2)
    add_column :opportunities, :inline_caption_3, :string unless column_exists?(:opportunities, :inline_caption_3)

    # Infos Organisation et Stats
    add_column :opportunities, :organization, :string unless column_exists?(:opportunities, :organization)
    add_column :opportunities, :stat_1_number, :string unless column_exists?(:opportunities, :stat_1_number)
    add_column :opportunities, :stat_1_label, :string unless column_exists?(:opportunities, :stat_1_label)
    add_column :opportunities, :stat_2_number, :string unless column_exists?(:opportunities, :stat_2_number)
    add_column :opportunities, :stat_2_label, :string unless column_exists?(:opportunities, :stat_2_label)
    add_column :opportunities, :stat_3_number, :string unless column_exists?(:opportunities, :stat_3_number)
    add_column :opportunities, :stat_3_label, :string unless column_exists?(:opportunities, :stat_3_label)
    add_column :opportunities, :stat_4_number, :string unless column_exists?(:opportunities, :stat_4_number)
    add_column :opportunities, :stat_4_label, :string unless column_exists?(:opportunities, :stat_4_label)
  end
end
