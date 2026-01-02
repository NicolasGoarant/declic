class AddAuthorFieldsToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :author_name, :string
    add_column :stories, :author_email, :string
    add_column :stories, :city, :string
  end
end
