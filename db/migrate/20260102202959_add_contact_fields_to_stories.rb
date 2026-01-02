class AddContactFieldsToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :phone, :string
    add_column :stories, :address, :string
    add_column :stories, :postal_code, :string
  end
end
