namespace :declic do
  desc "Rapport rapide sur les opportunités"
  task report: :environment do
    total = Opportunity.count
    by_cat = Opportunity.group(:category).count
    long_titles = Opportunity.where("LENGTH(title) > 160").count
    missing_cat = Opportunity.where(category: [nil, ""]).count
    missing_loc = Opportunity.where(location: [nil, ""]).count
    missing_time = Opportunity.where(time_commitment: [nil, ""]).count

    puts "=== Rapport Opportunités ==="
    puts "Total: #{total}"
    puts "Par catégorie: #{by_cat.inspect}"
    puts "Titres >160: #{long_titles}"
    puts "Catégorie manquante: #{missing_cat}"
    puts "Lieu manquant: #{missing_loc}"
    puts "Date/Horaires manquants: #{missing_time}"
    puts "— Exemples récents —"
    Opportunity.order(created_at: :desc).limit(5).each do |o|
      puts "- #{o.title} | #{o.category} | #{o.organization} | #{o.location} | #{o.time_commitment}"
    end
  end
end
