# db/seeds.rb

puts "🧹 Nettoyage de la base de données..."
Story.destroy_all
Opportunity.destroy_all

# ==============================================================================
# 1. LES BELLES HISTOIRES (STORIES)
# ==============================================================================
puts "📖 Création des Belles Histoires..."

stories_data = [
  {
    title: "Elle plaque la finance à Paris pour devenir fromagère affineuse",
    chapo: "Bénédicte a troqué ses fichiers Excel contre des tomes de fromage. Un retour aux sources et au terroir nancéien.",
    location: "21 Grande Rue, 54000 Nancy",
    latitude: 48.6936, longitude: 6.1832,
    happened_on: Date.new(2023, 6, 3),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?q=80&w=1600&auto=format&fit=crop",
    body: "..." # (Corps de l'histoire)
  },
  {
    title: "Il ramène la campagne en ville avec sa laiterie urbaine",
    chapo: "Matthieu voulait produire de ses mains. Il a installé une véritable laiterie en plein centre-ville.",
    location: "6 rue Saint-Nicolas, 54000 Nancy",
    latitude: 48.6885, longitude: 6.1852,
    happened_on: Date.new(2023, 4, 8),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1629198688000-71f23e745b6e?q=80&w=1600&auto=format&fit=crop",
    body: "..." # (Corps de l'histoire)
  },
  {
    title: "De la fonction publique au Coffee Shop : le pari d'Aude",
    chapo: "Ancienne professeure, Aude a profité du confinement pour réaliser son rêve d'ouvrir un café.",
    location: "Rue des Ponts, 54000 Nancy",
    latitude: 48.6875, longitude: 6.1820,
    happened_on: Date.new(2021, 12, 14),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=1600&auto=format&fit=crop",
    body: "..." # (Corps de l'histoire)
  },
  # (Gardez toutes les autres Histoires ici)
]

# --- BOUCLE DE CRÉATION DES HISTOIRES ---
stories_data.each do |data|
  story = Story.find_or_initialize_by(title: data[:title])
  story.assign_attributes(data)
  story.is_active = true

  story.save!

  # Force les coordonnées même si le geocoder échoue
  if data[:latitude] && data[:longitude]
    story.update_columns(latitude: data[:latitude], longitude: data[:longitude])
  end
end
puts "✅ #{Story.count} belles histoires créées."


# ==============================================================================
# 2. LES OPPORTUNITÉS (OPPORTUNITIES)
# ==============================================================================
puts "🚀 Création des Opportunités (Mélange CCI + Classiques, avec décalage)..."

opportunities_data = [
  # --- OPPORTUNITÉS CCI (Décalage appliqué ici) ---
  {
    title: "Réunion d'information « Prêt à vous lancer » (Base)",
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "CCI 54, 53 rue Stanislas, Nancy",
    latitude: 48.6912, longitude: 6.1789, # Coordonnée de base
    starts_at: DateTime.new(2025, 12, 9, 9, 30),
    image_url: "https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=800&q=80",
    description: "Première réunion d'information gratuite pour lancer votre idée."
  },
  {
    title: "Atelier « Micro-entrepreneur » (Décalé N°1)",
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "CCI 54, 53 rue Stanislas, Nancy",
    latitude: 48.6914, longitude: 6.1787, # Décalage léger (15-20 mètres)
    starts_at: DateTime.new(2025, 12, 11, 9, 30),
    image_url: "https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=800&q=80",
    description: "Comprendre le fonctionnement du régime micro-entrepreneur et ses règles."
  },
  {
    title: "Formation : Créer son entreprise (5 jours) (Décalé N°2)",
    category: "formation",
    organization: "CCI Formation",
    location: "CCI 54, 53 rue Stanislas, Nancy",
    latitude: 48.6910, longitude: 6.1791, # Décalage léger (15-20 mètres)
    starts_at: DateTime.new(2025, 12, 1, 9, 00),
    image_url: "https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=800&q=80",
    description: "5 jours intensifs pour tout verrouiller avant de vous lancer."
  },
  {
    title: "Soirée Communication non verbale",
    category: "rencontres",
    organization: "CCI Grand Nancy",
    location: "Nancy (Centre)",
    latitude: 48.6936, longitude: 6.1846,
    starts_at: DateTime.new(2025, 12, 10, 18, 00),
    image_url: "https://images.unsplash.com/photo-1576085898323-218337e3e43c?w=800&q=80",
    description: "**Gratuit.** Au-delà des mots, votre corps parle !"
  },

  # --- OPPORTUNITÉS CLASSIQUES (Vérifiées) ---
  {
    title: "Jetez ? Pas question ! Repair Café",
    category: "ecologiser",
    organization: "MJC Villers",
    location: "MJC Villers-lès-Nancy (54600)",
    latitude: 48.6732, longitude: 6.1518,
    starts_at: DateTime.new(2025, 12, 6, 14, 00),
    image_url: "https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800",
    description: "Apprenez à réparer vos objets du quotidien au lieu de les jeter."
  },
  {
    title: "Atelier Fresque du Climat",
    category: "ecologiser",
    organization: "Fresque 54",
    location: "Octroi Nancy, 47 Bd d'Austrasie",
    latitude: 48.6955, longitude: 6.1983,
    starts_at: DateTime.new(2025, 12, 12, 18, 00),
    image_url: "https://images.unsplash.com/photo-1542601906990-b4d3fb7d5fa5?q=80&w=800",
    description: "3 heures pour comprendre les enjeux climatiques en jouant avec des cartes."
  },
  {
    title: "Maraude solidaire",
    category: "benevolat",
    organization: "Croix Rouge",
    location: "Place Maginot, 54000 Nancy",
    latitude: 48.6890, longitude: 6.1780,
    starts_at: DateTime.new(2025, 12, 5, 20, 00),
    image_url: "https://images.unsplash.com/photo-1469571486292-0ba58a3f068b?q=80&w=800",
    description: "Apportez chaleur et écoute aux sans-abri lors d'une maraude en centre-ville."
  },
  {
    title: "Initiation au Code",
    category: "formation",
    organization: "Le Wagon / Epitech",
    location: "Rives de Meurthe, Nancy",
    latitude: 48.6960, longitude: 6.1950,
    starts_at: DateTime.new(2025, 12, 15, 18, 30),
    image_url: "https://images.unsplash.com/photo-1531482615713-2afd69097998?q=80&w=800",
    description: "Créez votre première page web en 2 heures. Ouvert aux débutants complets."
  },
  {
    title: "Soirée Jeux de Société",
    category: "rencontres",
    organization: "Médiathèque",
    location: "Médiathèque Manufacture, Nancy",
    latitude: 48.6980, longitude: 6.1750,
    starts_at: DateTime.new(2025, 12, 20, 14, 00),
    image_url: "https://images.unsplash.com/photo-1606167668584-78701c57f13d?q=80&w=800",
    description: "Rencontrez de nouvelles personnes autour d'un jeu de plateau."
  }
]

# --- BOUCLE DE CRÉATION DES OPPORTUNITÉS (FIX DE SÉCURITÉ) ---
opportunities_data.each do |data|
  op = Opportunity.find_or_initialize_by(title: data[:title])
  op.assign_attributes(data)
  op.is_active = true

  op.save!

  # Force les coordonnées pour garantir qu'elles restent
  if data[:latitude] && data[:longitude]
    op.update_columns(latitude: data[:latitude], longitude: data[:longitude])
  end
end

puts "✅ #{Opportunity.count} opportunités créées."
puts "🎉 Seed terminé !"
