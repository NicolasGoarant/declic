class AddContactInfoToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :contact_info, :text
  end
end
