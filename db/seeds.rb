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

# ===== Opportunités (fictives pour maquette) =====
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
# Les images doivent être dans app/assets/images/avatars/ (julien.png, emma.png, thomas.png, marie.png)
testimonials = [
  {
    name: "Julien",
    age: 31,
    role: "Organisateur d’événements",
    story: "La communauté m’a permis de créer des rencontres régulières dans mon quartier.",
    image_url: asset_url("avatars/julien.png")
  },
  {
    name: "Emma",
    age: 26,
    role: "Entrepreneuse sociale",
    story: "L’accompagnement m’a aidée à lancer mon projet de solidarité.",
    image_url: asset_url("avatars/emma.png")
  },
  {
    name: "Thomas",
    age: 28,
    role: "Développeur reconverti",
    story: "J’ai découvert une formation puis un job qui ont changé ma trajectoire.",
    image_url: asset_url("avatars/thomas.png")
  },
  {
    name: "Marie",
    age: 34,
    role: "Bénévole — Restos du Cœur",
    story: "Grâce à Déclic, j’ai trouvé une mission où je me sens utile chaque semaine.",
    image_url: asset_url("avatars/marie.png")
  }
]

created_t = 0
testimonials.each do |attrs|
  t = Testimonial.find_or_initialize_by(name: attrs[:name])
  t.assign_attributes(attrs)
  created_t += 1 if t.new_record?
  t.save!
end

# ===== Belles histoires (10 réelles/localisées) =====

# ===== Belles histoires (10 réelles/localisées) =====
stories = [
  {
    slug: "caseus-nancy",
    title: "CASEUS — Crèmerie-fromagerie (Nancy)",
    chapo: "Bénédicte, ex-finance à Paris, ouvre une fromagerie à Nancy.",
    description: "Retour au sens, commerce de proximité en Vieille-Ville.",
    location: "21 Grande Rue, 54000 Nancy",
    latitude: 48.693, longitude: 6.183,
    source_name: "Site officiel",
    source_url:  "https://caseus-nancy.fr/",
    image_url:   "https://caseus-nancy.fr/ims25/enseigne.png",
    body: <<~MD,
      ### Le déclic
      Après des années dans la finance, Bénédicte veut retrouver du concret, du local et du contact. Le fromage s’impose : produit vivant, saisonnier, qui raconte des paysans.

      ### Le projet
      Ouverture d’une crèmerie-fromagerie en Vieille-Ville. Sélection courte, affineurs et producteurs suivis, conseil à la coupe, plateaux sur mesure. Objectif : faire (re)découvrir des textures, maturations et accords.

      ### Les obstacles
      Quitter un CDI, financer la chambre froide et l’affinage, passer les normes d’hygiène, apprivoiser les pics de saison. La régularité d’approvisionnement a demandé une vraie relation fournisseurs.

      ### Impact local
      Un commerce de proximité, des dégustations, et la valorisation de fermes qui travaillent proprement et sont mieux rémunérées.

      **À retenir**
      - Vendre des produits vivants demande rigueur et pédagogie  
      - La confiance producteurs ↔︎ commerçants est le nerf de la guerre
    MD
    quote: "Revenir à Nancy et parler goût chaque jour : c’était le sens qui me manquait."
  },
  {
    slug: "laiterie-de-nancy",
    title: "La Laiterie de Nancy (Nancy)",
    chapo: "Matthieu quitte le salariat pour créer une laiterie urbaine.",
    description: "Fabrication sur place (yaourts, fromages) au lait de foin.",
    location: "6 Rue Saint-Nicolas, 54000 Nancy",
    latitude: 48.689, longitude: 6.187,
    source_name: "Site officiel",
    source_url:  "https://www.lalaiteriedenancy.fr/",
    image_url:   "https://static.wixstatic.com/media/9f3674e120564679859a204316cae6a8.jpg/v1/fill/w_250,h_166,al_c,q_90/9f3674e120564679859a204316cae6a8.jpg",
    body: <<~MD,
      ### Le déclic
      Matthieu rêve d’entreprendre utile. Il choisit le lait, symbole du quotidien, et veut prouver qu’une laiterie urbaine est possible.

      ### Le projet
      Fabrication sur place : yaourts, fromages frais, desserts lactés. Lait de foin payé au **juste prix**, transparence sur les recettes, atelier visible derrière la vitrine.

      ### Les étapes clés
      Formation, maîtrise HACCP, financement des cuves/pasteurisateur, premier panel clients. Les premiers mois sont consacrés à stabiliser recettes et rendements.

      ### Ce que ça change
      Des produits ultra-frais, un lien clair avec les éleveurs, et une pédagogie régulière auprès des clients et des écoles.

      **À retenir**
      - Savoir dire non à des volumes irréalistes  
      - L’histoire derrière le produit vend plus que le packaging
    MD
    quote: "Que chacun sache d’où vient le lait et qui on rémunère."
  },
  {
    slug: "seventheen-coffee-luneville",
    title: "SEVENTHÉEN Coffee — Coffee shop (Lunéville)",
    chapo: "Deux reconversions, puis ouverture d'un coffee shop.",
    description: "Café de spécialité, petite restauration, animations.",
    location: "57 Rue de la République, 54300 Lunéville",
    latitude: 48.591, longitude: 6.496,
    source_name: "Page officielle",
    source_url:  "https://seventheen-coffee.eatbu.com/?lang=fr",
    image_url:   "https://cdn.website.dish.co/media/5c/2f/2551554/SEVENTHEEN-Coffee-Luneville.jpg",
    body: <<~MD,
      ### Le parcours
      Plusieurs virages pro, des voyages, puis un coup de cœur pour la culture café de spécialité. Barista, torréfacteurs, latte-art : ils se forment avant d’ouvrir.

      ### L’expérience
      Origines précises, méthodes douces, espresso maîtrisé, petite restauration maison. Ateliers d’initiation et playlists soignées pour animer la journée.

      ### Les défis
      Trouver un local lumineux, gérer le flux du midi, tenir les coûts sans rogner sur le grain. Les habitués deviennent la meilleure com.

      **À retenir**
      - Un café de spécialité, c’est 80 % d’éducation bienveillante  
      - La constance d’extraction vaut plus qu’un menu trop long
    MD
    quote: "On sert un café, mais on partage surtout une culture."
  },
  {
    slug: "saveurs-exotics-toul",
    title: "Saveurs Exotics — Épicerie antillaise & africaine (Toul)",
    chapo: "Du conseil RH à l'entrepreneuriat local.",
    description: "Épicerie fine, ateliers cuisine, bar à salade.",
    location: "9 Rue Pont-des-Cordeliers, 54200 Toul",
    latitude: 48.682, longitude: 5.894,
    source_name: "Site officiel",
    source_url:  "https://www.saveurs-exotics.fr/",
    image_url:   "https://www.saveurs-exotics.fr/wp-content/uploads/2025/06/Slide1-compressed.jpg",
    body: <<~MD,
      ### Le déclic
      Après des années en RH, envie d’entreprendre “à taille humaine” et de valoriser des goûts d’enfance et d’ailleurs.

      ### La boutique
      Épicerie antillaise & africaine : condiments, farines, boissons, frais. Bar à salade, plats du jour et ateliers cuisine pour apprendre à apprivoiser les produits.

      ### L’impact
      La clientèle locale découvre de nouvelles recettes, la diaspora trouve des références de qualité. Les producteurs partenaires sont mis en avant.

      **À retenir**
      - Tester des paniers découverte accélère l’adoption  
      - Le conseil au rayon vaut toutes les campagnes
    MD
    quote: "Faire voyager les gens, sans quitter Toul."
  },
  {
    slug: "fred-taxi-saulxures",
    title: "Fred’Taxi — Artisan taxi (Saulxures-lès-Nancy)",
    chapo: "À 48 ans, Frédéric passe de cariste à artisan taxi.",
    description: "Reconversion, carte pro obtenue et création de sa société de taxi.",
    location: "38 Grande Rue, 54420 Saulxures-lès-Nancy",
    latitude: 48.654, longitude: 6.209,
    source_name: "",
    source_url:  "",
    image_url:   "",
    body: <<~MD,
      ### Le déclic
      À 48 ans, Frédéric veut gagner en liberté. Il prépare la carte pro, révise code/réglementation, puis crée son entreprise.

      ### Le métier
      Courses locales, scolaires, médicales, gares/aéroports. Ponctualité, propreté du véhicule, sourire : le trio qui fidélise. Outils : planning simple + messagerie pour confirmer.

      ### Les réalités
      Horaires décalés, gestion carburant/assurance, réponses rapides. Le bouche-à-oreille reste décisif, surtout au village.

      **À retenir**
      - Bien choisir sa zone de chalandise  
      - Dire non aux courses qui font perdre de l’argent
    MD
    quote: "Ce que je vends ? La fiabilité."
  },
 
      {
  slug: "lecrin-damelevieres",
  title: "L’Écrin Bar & Lounge (Damelevières)",
  chapo: "Ancienne salariée d’Ehpad, elle reprend un bar-lounge en centre-bourg.",
  description: "Reprise d’établissement, animations et nouvelle dynamique locale.",
  location: "19 Rue de la Libération, 54360 Damelevières",
  latitude: 48.573, longitude: 6.346,
  source_name: "L'Est Républicain (12/09/2025)",
  source_url:  "/stories/articles/lecrin-damelevieres.pdf",
  image_url:   "",
  body: <<~MD,
    ### Le déclic
    Après un poste en Ehpad, elle veut créer un lieu vivant, sûr et chaleureux. Elle reprend un bar, le rénove et peaufine une identité plus “lounge”.

    ### La proposition
    Carte courte, produits simples mais soignés, soirées à thème, scènes ouvertes, partenariats associatifs. Le lieu devient repère de quartier.

    ### Les coulisses
    Licence, voisinage, sécurité : anticipation et dialogue. Une communication sobre et régulière sur les réseaux fait la différence.

    **À retenir**
    - La programmation vaut autant que la déco  
    - Une charte de convivialité claire évite 90 % des soucis
  MD
  quote: "Un endroit où l’on se sent bien, tout simplement."
},



  {
    slug: "madame-bergamote-nancy",
    title: "Madame Bergamote — Salon de thé (Nancy)",
    chapo: "Un salon de thé artisanal près de Stanislas.",
    description: "Pâtisserie maison, boissons chaudes, ateliers créatifs.",
    location: "3 Grande Rue, 54000 Nancy",
    latitude: 48.695, longitude: 6.184,
    source_name: "Page officielle",
    source_url:  "https://madame-bergamote-nancy.eatbu.com/?lang=fr",
    image_url:   "https://cdn.website.dish.co/media/5f/a2/7245201/Madame-Bergamote-312987467-105901108988435-4889136544572526137-n-jpg.jpg",
    body: <<~MD,
      ### Le déclic
      Passion pâtisserie + envie de recevoir = un salon de thé artisanal à deux pas de Stanislas.

      ### L’expérience
      Gâteaux du jour, tartes de saison, thés infusés correctement, petites attentions. Sourcing farine/beurre/œufs de qualité, production quotidienne pour éviter le gaspillage.

      ### Les défis
      Rythme fournil/salle, météo capricieuse, pics week-end. Le carnet de commandes et la pré-commande en ligne lissent l’activité.

      **À retenir**
      - La fraîcheur se voit et… se goûte  
      - Moins de références, mais parfaitement exécutées
    MD
    quote: "La simplicité, quand elle est précise, devient un vrai luxe."
  },
  {
    slug: "galapaga-villers",
    title: "GALAPAGA — Concept-store éthique (Villers-lès-Nancy)",
    chapo: "Laure, éducatrice de jeunes enfants, lance une boutique responsable.",
    description: "Puériculture, jeux, mode et ateliers, partenaire de la monnaie locale Florain.",
    location: "34 Boulevard de Baudricourt, 54600 Villers-lès-Nancy",
    latitude: 48.672, longitude: 6.152,
    source_name: "",
    source_url:  "",
    image_url:   "",
    body: <<~MD,
      ### Le déclic
      Éducatrice de jeunes enfants, Laure veut un commerce aligné avec ses valeurs : utile, durable, pédagogique.

      ### Le concept
      Sélection de puériculture, jeux, mode et accessoires éthiques. Critères : matériaux, réparabilité, conditions de fabrication. Ateliers parents-enfants et partenariats avec la monnaie locale **Florain**.

      ### Les clés
      Transparence sur les prix, fiches pédagogiques, SAV soigné. Le magasin devient un lieu-ressource.

      **À retenir**
      - La preuve d’impact se construit produit par produit  
      - Former l’équipe au conseil “anti-greenwashing”
    MD
    quote: "Mieux acheter, c’est déjà agir."
  },
  {
    slug: "miss-cookies-nancy",
    title: "Miss Cookies Coffee (Nancy)",
    chapo: "Aude quitte la fonction publique pour ouvrir un coffee-shop franchisé.",
    description: "Coffee/snacking rue des Ponts, nouvelle vie entrepreneuriale.",
    location: "9 Rue des Ponts, 54000 Nancy",
    latitude: 48.693, longitude: 6.182,
    source_name: "Site officiel",
    source_url:  "https://www.misscookies.com/",
    image_url:   "https://www.misscookies.com/photos/produits-patisseries.jpg",
    body: <<~MD,
      ### Le virage
      Après la fonction publique, Aude choisit une franchise pour s’outiller vite (procédures, appro, marque) et se concentrer sur le service.

      ### Le quotidien
      Cookies, boissons chaudes, snacking du midi. Recrutement local, suivi de qualité, rythme soutenu en centre-ville. La vitrine vit au fil des saisons.

      ### Leçon
      Franchise ≠ facilité : c’est un cadre. L’exécution, l’accueil et la gestion des coûts font la différence.

      **À retenir**
      - Les process servent la constance  
      - Mesurer chaque poste (matière, casse, temps)
    MD
    quote: "Je voulais entreprendre, mais jamais seule."
  },
  {
    slug: "alexs-pastries-vandoeuvre",
    title: "Alex’s Pastries — Pâtisserie (Vandœuvre-lès-Nancy)",
    chapo: "Reconversion : de l’enseignement à la pâtisserie.",
    description: "Sur commande + ateliers à domicile.",
    location: "6 Rue Notre-Dame-des-Pauvres, 54500 Vandœuvre-lès-Nancy",
    latitude: 48.656, longitude: 6.176,
    source_name: "Site officiel",
    source_url:  "https://alexloulous.wixsite.com/alexspastries",
    image_url:   "https://static.wixstatic.com/media/d30316_7bde4702681c4fd5ab1446470d45bf88~mv2.jpeg/v1/fill/w_980,h_980,al_c,q_85/Entremets%20vanille%20fruits%20rouges.jpeg",
    body: <<~MD,
      ### Le déclic
      Alexandra quitte l’enseignement pour un CAP pâtisserie et des stages. Elle démarre à petite échelle : commandes, évènementiel, marché bio.

      ### Signature
      Entremets soignés, biscuits de voyage, options sur mesure (sans alcool, peu sucré). Le carnet en ligne simplifie devis et retraits.

      ### Montée en puissance
      Photos soignées, retours clients, partenariats avec salles/traiteurs. Chaque lot devient vitrine.

      **À retenir**
      - Tester petit, apprendre vite, réinvestir  
      - Un calendrier clair des disponibilités évite la charge mentale
    MD
    quote: "Je fabrique peu, mais très bien, pour de vraies personnes."
  }
]

created_stories = 0
stories.each do |attrs|
  attrs = attrs.dup
  quote = attrs.delete(:quote)

  s = Story.find_or_initialize_by(slug: attrs[:slug])
  created_stories += 1 if s.new_record?

  s.assign_attributes(
    title:        attrs[:title],
    chapo:        attrs[:chapo],
    description:  attrs[:description],
    body:         attrs[:body] || attrs[:description],
    image_url:    attrs[:image_url],
    source_name:  attrs[:source_name],
    source_url:   attrs[:source_url],
    location:     attrs[:location],
    latitude:     attrs[:latitude],
    longitude:    attrs[:longitude]
  )

  # Assigne la citation si la colonne existe
  if Story.column_names.include?("quote") && quote.present?
    s.assign_attributes(quote: quote)
  end

  s.save!
end

puts "Seeds -> stories: +#{created_stories} (total: #{Story.count})"

