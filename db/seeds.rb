Opportunity.destroy_all
Testimonial.destroy_all

Opportunity.create!([
  { title: "Aide alimentaire - Restos du Cœur", description: "Préparation et distribution de repas.",
    category: "benevolat", organization: "Restos du Cœur", location: "Paris 11ème",
    contact_email: "contact@restosducoeur.org", contact_phone: "01 42 00 00 00",
    tags: "solidarité,alimentation,équipe", effort_level: "modéré", time_commitment: "4h/semaine",
    latitude: 48.8566, longitude: 2.3522, is_active: true },
  { title: "Formation développeur web", description: "Bootcamp intensif 6 mois.",
    category: "formation", organization: "Le Wagon", location: "Paris 9ème",
    contact_email: "admissions@lewagon.com", contact_phone: "01 76 00 00 00",
    tags: "technologie,carrière,intensif", effort_level: "intensif", time_commitment: "35h/semaine",
    latitude: 48.8742, longitude: 2.3386, is_active: true }
])

Testimonial.destroy_all
Testimonial.create!([
  { name:"Marie", age:34, role:"Bénévole aux Restos du Cœur",
    story:"Grâce à Déclic, j’ai trouvé une mission de distribution de repas à deux stations de métro de chez moi. J’y vais chaque semaine, j’ai rencontré une équipe bienveillante et j’ai repris confiance en moi.",
    image_url:"https://images.unsplash.com/photo-1494790108755-2616b612b851?w=150" },
  { name:"Thomas", age:28, role:"Développeur reconverti",
    story:"Je voulais changer de voie sans retourner à l’école pendant des années. J’ai découvert une formation intensive, puis un stage. Aujourd’hui, je code pour une coopérative qui a du sens pour moi.",
    image_url:"https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150" },
  { name:"Emna", age:26, role:"Entrepreneuse sociale",
    story:"J’avais une idée de café associatif mais je ne savais pas par où commencer. Grâce aux rencontres et à l’accompagnement trouvés via Déclic, j’ai rédigé mon business plan et j’ai ouvert un lieu de quartier.",
    image_url:"https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150" },
  { name:"Julien", age:31, role:"Organisateur d’événements",
    story:"Je me sentais isolé après un déménagement. Les événements de la communauté m’ont permis de créer un groupe de bénévoles réguliers. On organise désormais une collecte solidaire chaque mois.",
    image_url:"https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=150" },
  { name:"Aïcha", age:22, role:"Étudiante engagée",
    story:"Entre les cours et un petit job, je pensais ne pas avoir le temps. J’ai trouvé des micro-missions d’une heure qui me permettent d’aider ponctuellement sans pression, quand je peux.",
    image_url:"https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150" },
  { name:"Marc", age:45, role:"Coach bénévole",
    story:"Partager mon expérience pro avec des jeunes en reconversion m’a redonné de l’énergie. J’accompagne désormais une promo de 15 personnes, et je vois leurs progrès semaine après semaine.",
    image_url:"https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=150" }
])


require "securerandom"

CITIES = [
  # Paris & Nancy plusieurs fois pour pondérer
  {city:"Paris 9e",   lat:48.8742, lng:2.3386},
  {city:"Paris 11e",  lat:48.8570, lng:2.3770},
  {city:"Paris 13e",  lat:48.8270, lng:2.3550},
  {city:"Paris 18e",  lat:48.8924, lng:2.3443},
  {city:"Nancy Centre", lat:48.6921, lng:6.1844},
  {city:"Nancy Rives",  lat:48.6840, lng:6.1690},
  {city:"Nancy Artem",  lat:48.6765, lng:6.1600},

  # Grand Ouest / Nord / Sud / Est
  {city:"Lyon",      lat:45.7640, lng:4.8357},
  {city:"Lille",     lat:50.6292, lng:3.0573},
  {city:"Bordeaux",  lat:44.8378, lng:-0.5792},
  {city:"Marseille", lat:43.2965, lng:5.3698},
  {city:"Toulouse",  lat:43.6045, lng:1.4440},
  {city:"Nantes",    lat:47.2184, lng:-1.5536},
  {city:"Rennes",    lat:48.1173, lng:-1.6778},
  {city:"Strasbourg",lat:48.5734, lng:7.7521},
  {city:"Montpellier",lat:43.6119,lng:3.8772},
  {city:"Grenoble",  lat:45.1885, lng:5.7245},
  {city:"Dijon",     lat:47.3220, lng:5.0415},
  {city:"Angers",    lat:47.4784, lng:-0.5632},
  {city:"Tours",     lat:47.3941, lng:0.6848},
  {city:"Metz",      lat:49.1193, lng:6.1757},
  {city:"Reims",     lat:49.2583, lng:4.0317},
  {city:"Rouen",     lat:49.4432, lng:1.0993},
  {city:"Nice",      lat:43.7102, lng:7.2620},
  {city:"Clermont-Ferrand", lat:45.7772, lng:3.0870},
  {city:"Poitiers",  lat:46.5802, lng:0.3404},
  {city:"Besançon",  lat:47.2378, lng:6.0241},
  {city:"Amiens",    lat:49.8941, lng:2.2958}
]

CATEGORIES = %w[benevolat formation rencontres entreprendre]
ORGS = [
  "Restos du Cœur","Croix-Rouge","Secours Populaire","Emmaüs","AFEV","Le Wagon",
  "MJC Locale","Mission Locale","Pôle Asso","Incubateur Territoire","Makers Lab",
  "Centre Social", "Simplon", "Club Sport Solidaire", "Bibliothèque Citoyenne"
]

TITLES = {
  "benevolat"   => ["Aide alimentaire","Accompagnement scolaire","Visite de convivialité","Réparation solidaire","Collecte de dons","Jardin partagé"],
  "formation"   => ["Formation développeur web","Atelier numérique","Formation premiers secours","Bootcamp data","Initiation éco-citoyenne","Atelier CV & emploi"],
  "rencontres"  => ["Café-rencontre","Atelier de conversation","Soirée bénévole","Forum associatif","Meetup tech solidaire","Cercle de lecture"],
  "entreprendre"=> ["Incubation projet","Coaching entrepreneurial","Atelier business plan","Pitch night","Hackathon solidaire","Accompagnement ESS"]
}

def pick_city
  # Favorise Paris et Nancy (présentes plusieurs fois) en tirage
  CITIES.sample
end

def title_for(cat); TITLES[cat].sample; end

def desc_for(cat)
  case cat
  when "benevolat"   then "Rejoignez une équipe chaleureuse pour agir concrètement près de chez vous."
  when "formation"   then "Montez en compétences avec un parcours structuré et accompagné."
  when "rencontres"  then "Créez des liens authentiques au sein d’une communauté bienveillante."
  else                    "Lancez votre projet avec l’aide de mentors et d’un réseau d’entraide."
  end
end

opps = []

120.times do
  cat = CATEGORIES.sample
  c   = pick_city
  opps << {
    title:        "#{title_for(cat)}",
    description:  desc_for(cat),
    category:     cat,
    organization: ORGS.sample,
    location:     c[:city],
    contact_email:"contact@#{ORGS.sample.downcase.gsub(/\s+/, '')}.org",
    contact_phone:"01 #{rand(10..99)} #{rand(10..99)} #{rand(10..99)} #{rand(10..99)}",
    tags:         %w[solidarité local entraide compétences].sample(2).join(","),
    effort_level: %w[léger modéré intensif].sample,
    time_commitment: ["2h/semaine","4h/semaine","1j/semaine","Ponctuel"].sample,
    latitude:     (c[:lat]  + rand(-0.020..0.020)).round(6),
    longitude:    (c[:lng] + rand(-0.020..0.020)).round(6),
    is_active:    [true,true,true,false].sample # majoritairement vrai
  }
end

Opportunity.insert_all!(opps)

Testimonial.create!([
  { name:"Marie", age:34, role:"Bénévole aux Restos du Cœur",
    story:"Grâce à Déclic, j'ai trouvé une mission où je me sens utile chaque semaine.",
    image_url:"https://images.unsplash.com/photo-1494790108755-2616b612b851?w=150" },
  { name:"Thomas", age:28, role:"Développeur reconverti",
    story:"J’ai découvert une formation puis un job qui ont changé ma trajectoire.",
    image_url:"https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150" },
  { name:"Emna", age:26, role:"Entrepreneuse sociale",
    story:"L’accompagnement m’a aidée à lancer mon projet d’atelier solidaire.",
    image_url:"https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150" },
  { name:"Julien", age:31, role:"Organisateur d’événements",
    story:"La communauté m’a permis de créer des rencontres régulières dans mon quartier.",
    image_url:"https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=150" }
])