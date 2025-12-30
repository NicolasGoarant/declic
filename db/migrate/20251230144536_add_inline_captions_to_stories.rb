class AddInlineCaptionsToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :inline_caption_1, :string
    add_column :stories, :inline_caption_2, :string
    add_column :stories, :inline_caption_3, :string
  end
end
