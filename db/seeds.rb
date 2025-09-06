# db/seeds.rb
# Idempotent, compatible Heroku (Postgres + assets précompilés)

# ===== Helpers =====
CATEGORIES = %w[benevolat formation rencontres entreprendre].freeze

def jitter(lat, lon, km_max = 3.0)
  # ~1° lat = 111 km ; long corrigée par cos(lat)
  dlat = (rand * 2 - 1) * (km_max / 111.0)
  dlon = (rand * 2 - 1) * (km_max / (111.0 * Math.cos(lat * Math::PI / 180)))
  [lat + dlat, lon + dlon]
end

def mk(loc:, lat:, lon:, n:, category:, orgs:, titles:, city_label: nil)
  n.times.map do
    t = titles.sample
    o = orgs.sample
    la, lo = jitter(lat, lon, 2.5)
    {
      title: t,
      description: "💡 #{t}. Rejoins-nous pour une expérience concrète et utile. Encadrement bienveillant, matériel fourni selon besoin.",
      category: category,
      organization: o,
      location: city_label || loc,
      time_commitment: ["1–2 h", "2–4 h", "Ponctuel", "Hebdomadaire", "Mensuel"].sample,
      latitude: la.round(6),
      longitude: lo.round(6),
      is_active: true,
      tags: %w[accueil débutant convivial réseau impact].sample(3).join(", ")
    }
  end
end

# Helper pour produire l'URL fingerprintée d'un asset (production Heroku)
def asset_url(path)
  # ex: "avatars/julien.jpg" -> "/assets/avatars/julien-abcdef123.jpg"
  ActionController::Base.helpers.asset_path(path)
rescue
  # fallback minimal si jamais les helpers ne sont pas dispo
  "/assets/#{path}"
end

# ===== Données de base =====
paris = { city: "Paris",  lat: 48.8566,   lon: 2.3522 }
nancy = { city: "Nancy",  lat: 48.692054, lon: 6.184417 }

benevolat_titles = [
  "Aide alimentaire - distribution",
  "Collecte solidaire",
  "Maraude du soir",
  "Atelier devoirs",
  "Tri de dons",
  "Accompagnement numérique",
  "Accueil évènement",
  "Jardin partagé - coup de main",
  "Repair Café - accueil",
  "Frigo solidaire - réassort"
]

formation_titles = [
  "Découverte du code (initiation)",
  "Atelier CV & LinkedIn",
  "Formation premiers secours",
  "Atelier podcast - initiation",
  "Webinaire reconversion",
  "Atelier pitch de projet",
  "Formation outils collaboratifs",
  "Starter Design Thinking"
]

rencontres_titles = [
  "Café-rencontre bienveillance",
  "Apéro associatif",
  "Cercle de lecture engagé",
  "Balade urbaine solidaire",
  "Soirée jeux coopératifs",
  "Initiation compost collectif",
  "Visite tiers-lieu"
]

entreprendre_titles = [
  "Permanence pro bono (stratégie)",
  "Mentorat entrepreneur·e",
  "Atelier business model",
  "Office hours juridique",
  "Club entrepreneurs à impact",
  "Sprint produit (2h)",
  "Atelier finance d'amorçage"
]

orgs_common = [
  "Restos du Cœur", "Secours Populaire", "Emmaüs",
  "MJC Locale", "Tiers-Lieu Citoyen", "Bibliothèque Solidaire",
  "Réseau Entourage", "Collectif Zéro Déchet", "Pôle Asso"
]
orgs_paris = orgs_common + ["Le Wagon", "Makesense", "Latitudes", "Simplon", "Fab City"]
orgs_nancy = orgs_common + ["Métropole Grand Nancy", "Université de Lorraine", "La fabrique des possibles"]

# ===== Opportunités =====
records = []
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n: 14, category: "benevolat",    orgs: orgs_paris, titles: benevolat_titles)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n: 10, category: "formation",    orgs: orgs_paris, titles: formation_titles)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n:  8, category: "rencontres",   orgs: orgs_paris, titles: rencontres_titles)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n:  6, category: "entreprendre", orgs: orgs_paris, titles: entreprendre_titles)

records += mk(loc: "Nancy", lat: nancy[:lat], lon: nancy[:lon], n:  6, category: "benevolat",    orgs: orgs_nancy, titles: benevolat_titles)
records += mk(loc: "Nancy", lat: nancy[:lat], lon: nancy[:lon], n:  4, category: "formation",    orgs: orgs_nancy, titles: formation_titles)
records += mk(loc: "Nancy", lat: nancy[:lat], lon: nancy[:lon], n:  4, category: "rencontres",   orgs: orgs_nancy, titles: rencontres_titles)
records += mk(loc: "Nancy", lat: nancy[:lat], lon: nancy[:lon], n:  4, category: "entreprendre", orgs: orgs_nancy, titles: entreprendre_titles)

# Quelques autres villes
{ "Lyon" => [45.7640, 4.8357], "Rennes" => [48.1173, -1.6778], "Lille" => [50.6292, 3.0573] }.each do |city, (lat, lon)|
  records += mk(loc: city, lat: lat, lon: lon, n: 2, category: "rencontres", orgs: orgs_common, titles: rencontres_titles, city_label: city)
end

created_opps = 0
records.each do |h|
  # idempotent : on évite les doublons grossiers
  found = Opportunity.find_or_initialize_by(title: h[:title], organization: h[:organization], location: h[:location])
  found.assign_attributes(h)
  created_opps += 1 if found.new_record?
  found.save!
end

# ===== Témoignages =====
# Les images doivent être dans app/assets/images/avatars/ (julien.jpg, emma.jpg, thomas.jpg, marie.jpg)
testimonials = [
  {
    name: "Julien",
    age: 31,
    role: "Organisateur d’événements",
    story: "La communauté m’a permis de créer des rencontres régulières dans mon quartier.",
    image_url: asset_url("avatars/julien.jpg")
  },
  {
    name: "Emma",
    age: 26,
    role: "Entrepreneuse sociale",
    story: "L’accompagnement m’a aidée à lancer mon projet de solidarité.",
    image_url: asset_url("avatars/emma.jpg")
  },
  {
    name: "Thomas",
    age: 28,
    role: "Développeur reconverti",
    story: "J’ai découvert une formation puis un job qui ont changé ma trajectoire.",
    image_url: asset_url("avatars/thomas.jpg")
  },
  {
    name: "Marie",
    age: 34,
    role: "Bénévole — Restos du Cœur",
    story: "Grâce à Déclic, j’ai trouvé une mission où je me sens utile chaque semaine.",
    image_url: asset_url("avatars/marie.jpg")
  }
]

created_t = 0
testimonials.each do |attrs|
  t = Testimonial.find_or_initialize_by(name: attrs[:name])
  t.assign_attributes(attrs)
  created_t += 1 if t.new_record?
  t.save!
end

puts "Seeds -> opportunities: +#{created_opps} (total: #{Opportunity.count})"
puts "Seeds -> testimonials:  +#{created_t} (total: #{Testimonial.count})"
