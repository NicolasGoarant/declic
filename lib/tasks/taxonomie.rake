# frozen_string_literal: true

namespace :taxonomie do
  desc "Remplace « rencontres » par Pratiquer/Découvrir. Sans APPLIQUER=1 : affiche seulement ce qui serait fait."
  task recategoriser: :environment do
    passage = Taxonomie::Recategorisation.new
    liste = passage.changements
    liste.each { |c| puts [ c.id, c.vers, c.origine, c.titre ].join(" | ") }
    puts "#{liste.size} fiches : #{liste.map(&:vers).tally}"
    if ENV["APPLIQUER"] == "1"
      bilan = passage.appliquer
      puts "APPLIQUÉ : #{bilan[:fiches].size} fiches, #{bilan[:candidats]} candidats. Restent en « rencontres » : " \
           "#{Opportunity.where(category: 'rencontres').count} fiches, #{Veille::Candidate.where(declic_category: 'rencontres').count} candidats."
    else
      puts "Rien d'écrit (APPLIQUER=1 pour écrire)."
    end
  end
end
