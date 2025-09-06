class AddContentAndAvatarToTestimonials < ActiveRecord::Migration[7.2]
  def change
    # On ajoute les colonnes réellement utilisées par l'app
    add_column :testimonials, :story, :text   unless column_exists?(:testimonials, :story)
    add_column :testimonials, :image_url, :string unless column_exists?(:testimonials, :image_url)

    # On nettoie d’éventuelles colonnes obsolètes
    remove_column :testimonials, :content if column_exists?(:testimonials, :content)
    remove_column :testimonials, :avatar  if column_exists?(:testimonials, :avatar)
  end
end
