class AddContentToTestimonials < ActiveRecord::Migration[7.2]
  def change
    add_column :testimonials, :content, :text
  end
end
