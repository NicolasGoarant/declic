class PagesController < ApplicationController
  # désactive le layout pour home (sinon DOCTYPE s’affiche dans la page)

  def home
    @journey_cards = [
      { id: 1, category: 'benevolat',   title: 'Je veux aider',        description: 'Trouvez des missions de bénévolat qui correspondent à vos valeurs', icon: 'heart',     color: 'bg-gradient-to-br from-red-500 to-pink-600' },
      { id: 2, category: 'formation',   title: 'Je veux apprendre',    description: 'Découvrez des formations pour développer vos compétences',        icon: 'book-open', color: 'bg-gradient-to-br from-blue-500 to-indigo-600' },
      { id: 3, category: 'rencontres',  title: 'Je veux rencontrer',   description: 'Rejoignez des communautés et créez des liens authentiques',       icon: 'users',     color: 'bg-gradient-to-br from-green-500 to-teal-600' },
      { id: 4, category: 'entreprendre',title: 'Je veux entreprendre', description: "Lancez votre projet avec le soutien d'entrepreneurs expérimentés", icon: 'briefcase', color: 'bg-gradient-to-br from-orange-500 to-red-600' }
    ]
    @opportunities = Opportunity.where(is_active: true)
    @testimonials  = Testimonial.all
  end
end
