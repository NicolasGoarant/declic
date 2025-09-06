class AddContentAndAvatarToTestimonials < ActiveRecord::Migration[7.2]
  def change
    add_column :testimonials, :content, :text
    add_column :testimonials, :avatar, :string
  end
end
