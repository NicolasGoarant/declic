# db/seeds.rb
# Idempotent, compatible Heroku (Postgres)

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

# Helper pour l'URL fingerprintée d'un asset (prod Heroku)
def asset_url(path)
  ActionController::Base.helpers.asset_path(path)
rescue
  "/assets/#{path}"
end

def add_link(desc, url)
  [desc.to_s.strip, "\n\n🔗 En savoir plus : #{url}"].join
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

# ===== Opportunités (maquettes Paris) =====
records = []
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n: 14, category: "benevolat",    orgs: orgs_paris, titles: benevolat_titles)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n: 10, category: "formation",    orgs: orgs_paris, titles: formation_titles)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n:  8, category: "rencontres",   orgs: orgs_paris, titles: rencontres_titles)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n:  6, category: "entreprendre", orgs: orgs_paris, titles: entreprendre_titles)

# ===== Nancy (réel/curation locale) =====
nancy_real = [
  # ENTREPRENDRE
  {
    title: "Atelier — Construire son Business Plan",
    description: add_link("CCI Grand Nancy : méthodologie, trame financière, hypothèses clés. Conseils personnalisés pour pitcher et convaincre.",
                          "https://www.nancy.cci.fr/evenements"),
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Jeudi 10/10, 14:00–17:00",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "business plan,financement,atelier"
  },
  {
    title: "Permanence création d’entreprise (sur RDV)",
    description: add_link("Entretien individuel : statut, aides, étapes de la création. Orientation vers partenaires (BPI, CMA, réseaux).",
                          "https://www.nancy.cci.fr/evenements"),
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Hebdomadaire — sur rendez-vous",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "diagnostic,statuts,accompagnement"
  },
  {
    title: "Afterwork Entrepreneurs Nancy",
    description: add_link("Rencontres entre porteurs de projet, mentors, experts locaux. Pitches libres, retours d’expérience, réseautage.",
                          "https://www.nancy.cci.fr/evenements"),
    category: "entreprendre",
    organization: "Réseau local (CCI & partenaires)",
    location: "Centre-ville, 54000 Nancy",
    time_commitment: "Mensuel, 18:30–20:30",
    latitude: 48.6918, longitude: 6.1837,
    is_active: true, tags: "réseau,pitch,mentorat"
  },
  {
    title: "Atelier — Financer son projet",
    description: add_link("Panorama des financements : prêts, subventions, love money, dispositifs région. Préparer son dossier et son prévisionnel.",
                          "https://www.nancy.cci.fr/evenements"),
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Vendredi 25/10, 09:30–12:00",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "financement,bpi,subventions"
  },
  {
    title: "Mentorat entrepreneur·e — rendez-vous découverte",
    description: add_link("Matching avec mentors (stratégie, juridique, produit). Objectif : clarifier la feuille de route 90 jours.",
                          "https://communs-entrepreneurs.fr"),
    category: "entreprendre",
    organization: "Communs d’entrepreneurs Nancy",
    location: "Nancy & Métropole",
    time_commitment: "Sur candidature",
    latitude: 48.692, longitude: 6.184,
    is_active: true, tags: "mentorat,roadmap,coaching"
  },

  # FORMATION
  {
    title: "Atelier Pitch & Storytelling",
    description: add_link("Structurer un pitch clair et mémorable : problème, solution, traction. Exercices filmés + feedback.",
                          "https://www.nancy.cci.fr/evenements"),
    category: "formation",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Mercredi 16/10, 14:00–17:00",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "pitch,communication,atelier"
  },
  {
    title: "Matinale Numérique — TPE/PME",
    description: add_link("Référencement local, réseaux sociaux, outils no-code. Cas pratiques d’entreprises du territoire.",
                          "https://www.nancy.cci.fr/evenements"),
    category: "formation",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Mensuel, 08:30–10:00",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "numérique,seo,no-code"
  },
  {
    title: "Découvrir la méthodologie HACCP (restauration)",
    description: add_link("Sensibilisation aux bonnes pratiques d’hygiène et aux points critiques — prérequis avant ouverture.",
                          "https://www.nancy.cci.fr/evenements"),
    category: "formation",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Session bimensuelle",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "haccp,restauration,hygiène"
  },

  # RENCONTRES
  {
    title: "Café-projets — échanges entre pairs",
    description: add_link("Partage d’avancées, obstacles et ressources. Format court, bienveillant, ouvert aux débutant·es.",
                          "https://www.grandnancy.eu"),
    category: "rencontres",
    organization: "Communauté Déclic Nancy",
    location: "Place Stanislas, 54000 Nancy",
    time_commitment: "Tous les 15 jours, 18:30",
    latitude: 48.6937, longitude: 6.1834,
    is_active: true, tags: "pair-à-pair,entraide,réseau"
  },
  {
    title: "Visite — Tiers-lieu & fablab",
    description: add_link("Découverte des machines + ateliers à venir. Idéal pour prototyper et rencontrer des makers.",
                          "https://lafabriquedespossibles.fr"),
    category: "rencontres",
    organization: "La Fabrique des Possibles",
    location: "Nancy",
    time_commitment: "Mensuel",
    latitude: 48.682, longitude: 6.186,
    is_active: true, tags: "tiers-lieu,fablab,prototype"
  },

  # BÉNÉVOLAT
  {
    title: "Repair Café — accueil & logistique",
    description: add_link("Accueil du public, orientation, aide à la tenue du stand. Ambiance conviviale, sensibilisation anti-gaspillage.",
                          "https://mjc-bazin.fr"),
    category: "benevolat",
    organization: "MJC Bazin",
    location: "47 Rue Henri Bazin, 54000 Nancy",
    time_commitment: "Mensuel, samedi matin",
    latitude: 48.6848, longitude: 6.1899,
    is_active: true, tags: "réparation,accueil,convivial"
  },
  {
    title: "Atelier couture — coup de main",
    description: add_link("Aider à l’atelier : prise de mesures, préparation du matériel, accompagnement débutant·es.",
                          "https://mjc-bazin.fr"),
    category: "benevolat",
    organization: "MJC Bazin",
    location: "47 Rue Henri Bazin, 54000 Nancy",
    time_commitment: "Hebdomadaire",
    latitude: 48.6848, longitude: 6.1899,
    is_active: true, tags: "couture,atelier,pédagogie"
  },
  {
    title: "Distribution alimentaire",
    description: add_link("Renfort sur la distribution, accueil et réassort. Esprit d’équipe, respect et confidentialité.",
                          "https://www.restosducoeur.org/devenir-benevole/"),
    category: "benevolat",
    organization: "Restos du Cœur — Nancy",
    location: "Centre-ville, 54000 Nancy",
    time_commitment: "Hebdomadaire (créneaux 2–3 h)",
    latitude: 48.689, longitude: 6.184,
    is_active: true, tags: "solidarité,logistique,accueil"
  },
  {
    title: "Tri de dons & mise en rayon",
    description: add_link("Collecte, tri, étiquetage. Participer au circuit de revalorisation et à la boutique solidaire.",
                          "https://www.secourspopulaire.fr"),
    category: "benevolat",
    organization: "Secours Populaire — Nancy",
    location: "Nancy",
    time_commitment: "2–4 h / semaine",
    latitude: 48.69, longitude: 6.18,
    is_active: true, tags: "tri,solidarité,boutique"
  },
  {
    title: "Maraude & lien social",
    description: add_link("Aller à la rencontre, distribuer boissons chaudes, orienter vers partenaires. Travail en binôme.",
                          "https://www.francebenevolat.org"),
    category: "benevolat",
    organization: "Réseau local (associatif)",
    location: "Nancy — différents quartiers",
    time_commitment: "Soirées (2–3 h)",
    latitude: 48.692, longitude: 6.184,
    is_active: true, tags: "maraude,écoute,orientation"
  }
]
records += nancy_real

# ===== Corridor Nancy ↔ Saint-Dié (opportunités typiques) =====
vosges_corridor = [
  # ENTREPRENDRE / REPRISE
  {
    title: "Reprise d’un café associatif",
    description: "L'association « Café des Possibles » cherche un·e repreneur·se pour faire vivre concerts, ateliers et rencontres.",
    category: "entreprendre",
    organization: "Café des Possibles",
    location: "Lunéville",
    latitude: 48.5930, longitude: 6.4978,
    time_commitment: "Étude + passation (3 mois)",
    is_active: true, tags: "reprise,café associatif,programmation"
  },
  {
    title: "Créer un tiers-lieu rural (local municipal disponible)",
    description: "Coworking + atelier vélo + café associatif. Appel à porteurs de projet et partenaires.",
    category: "entreprendre",
    organization: "Commune de Baccarat",
    location: "Baccarat",
    latitude: 48.4500, longitude: 6.7383,
    time_commitment: "Appel à projets",
    is_active: true, tags: "tiers-lieu,collectif,local disponible"
  },

  # FORMATION / WORKSHOPS
  {
    title: "Stage découverte — Savoirs-faire artisanaux",
    description: "Week-end d’initiation (bois, céramique, textile) — zéro prérequis, matériel prêté.",
    category: "formation",
    organization: "Maison des Savoir-Faire",
    location: "Raon-l'Étape",
    latitude: 48.4011, longitude: 6.8428,
    time_commitment: "2 jours (samedi-dimanche)",
    is_active: true, tags: "artisanat,initiation,week-end"
  },
  {
    title: "Atelier d’entrepreneuriat local",
    description: "Construire un mini-plan d’action en 2 jours, coaching collectif et individuel.",
    category: "formation",
    organization: "Incubateur Grand Est Rural",
    location: "Saint-Dié-des-Vosges",
    latitude: 48.2851, longitude: 6.9498,
    time_commitment: "2 jours",
    is_active: true, tags: "entrepreneuriat,coaching,projet"
  },

  # BÉNÉVOLAT / ÉVÉNEMENTS
  {
    title: "Organisation d’un festival éco-responsable",
    description: "Rejoindre l’équipe bénévole : logistique, accueil, médiation. Hébergement + repas fournis.",
    category: "benevolat",
    organization: "Collectif Forêts & Futurs",
    location: "Bruyères",
    latitude: 48.2091, longitude: 6.7158,
    time_commitment: "1 semaine en été",
    is_active: true, tags: "festival,écologie,accueil"
  },
  {
    title: "Épicerie coopérative — coup de main",
    description: "Distribution, gestion des stocks, accueil sociétaires.",
    category: "benevolat",
    organization: "Les Paniers Solidaires",
    location: "Saint-Nicolas-de-Port",
    latitude: 48.6331, longitude: 6.3031,
    time_commitment: "2–3 h / semaine",
    is_active: true, tags: "coopérative,épicerie,logistique"
  }
]
records += vosges_corridor

# ===== Autres villes (légère maquette pour carte) =====
{ "Lyon" => [45.7640, 4.8357], "Rennes" => [48.1173, -1.6778], "Lille" => [50.6292, 3.0573] }.each do |city, (lat, lon)|
  records += mk(loc: city, lat: lat, lon: lon, n: 2, category: "rencontres", orgs: orgs_common, titles: rencontres_titles, city_label: city)
end

# ===== Insertion idempotente (Opportunities) =====
created_opps = 0
records.each do |h|
  found = Opportunity.find_or_initialize_by(title: h[:title], organization: h[:organization], location: h[:location])
  found.assign_attributes(h)
  created_opps += 1 if found.new_record?
  found.save!
end
puts "Seeds -> opportunities: +#{created_opps} (total: #{Opportunity.count})"

# ===== Témoignages =====
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
puts "Seeds -> testimonials: +#{created_t} (total: #{Testimonial.count})"

# ===== Belles histoires (localisées) =====
stories = [
  # Nancy (existants)
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
      Ouverture d’une crèmerie-fromagerie en Vieille-Ville. Sélection courte, affineurs et producteurs suivis, conseil à la coupe, plateaux sur mesure.

      ### Obstacles
      Financements, normes d’hygiène, régularité d’approvisionnement. La relation avec les producteurs est clé.

      ### Impact local
      Dégustations, mise en valeur des fermes, dynamisation du quartier.
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
    source_name: "Article PDF",
    source_url:  "/stories/articles/laiterie-urbaine.pdf",
    image_url:   "https://static.wixstatic.com/media/9f3674e120564679859a204316cae6a8.jpg/v1/fill/w_250,h_166,al_c,q_90/9f3674e120564679859a204316cae6a8.jpg",
    body: <<~MD,
      ### Le déclic
      Prouver qu’une laiterie urbaine est possible et juste.

      ### Le projet
      Production visible depuis la boutique, lait payé au juste prix, transparence sur les recettes.

      ### Étapes
      HACCP, financement des cuves, stabilisation des recettes, premiers clients.

      ### Ce que ça change
      Produits ultra-frais, lien direct éleveurs, pédagogie locale.
    MD
    quote: "Que chacun sache d’où vient le lait et qui on rémunère."
  },

  # Corridor Nancy ↔ Saint-Dié — Belles histoires
  {
    slug: "friche-en-lieu-baccarat",
    title: "Ils transforment une friche en café culturel (Baccarat)",
    chapo: "Un collectif réhabilite un ancien site en lieu culturel.",
    description: "Café associatif, concerts, atelier réparation, ressourcerie.",
    location: "Baccarat",
    latitude: 48.4500, longitude: 6.7383,
    source_name: "Collectif local",
    source_url:  "",
    image_url:   "",
    body: <<~MD,
      ### Le déclic
      Face à une friche au cœur de la ville, un collectif rassemble habitants et assos.

      ### Le projet
      Café culturel, programmation locale, ressourcerie et ateliers de transmission.

      ### À retenir
      - Convention d’occupation claire avec la mairie  
      - Gouvernance simple + transparence financière
    MD
    quote: "On a rallumé une lumière au centre-bourg."
  },
  {
    slug: "menuiserie-reconversion-raon",
    title: "De demandeur d’emploi à artisan menuisier (Raon-l’Étape)",
    chapo: "Jean se forme en atelier partagé, devient artisan.",
    description: "Atelier bois, chantiers locaux, transmission à des apprentis.",
    location: "Raon-l'Étape",
    latitude: 48.4011, longitude: 6.8428,
    source_name: "Atelier partagé",
    source_url:  "",
    image_url:   "",
    body: <<~MD,
      ### Le déclic
      Travailler de ses mains, utile, local.

      ### Le chemin
      Formations courtes + compagnonnage en atelier mutualisé.

      ### Leçons
      - Petits chantiers au départ, bouche-à-oreille ensuite  
      - Qualité et délais = réputation
    MD
    quote: "Chaque pièce a une histoire, comme les maisons qu’on répare."
  },
  {
    slug: "coop-citoyenne-saint-die",
    title: "Une coopérative citoyenne qui change la ville (Saint-Dié)",
    chapo: "Habitants, assos et collectivités co-investissent.",
    description: "Locaux vacants rachetés, commerces et logements abordables.",
    location: "Saint-Dié-des-Vosges",
    latitude: 48.2851, longitude: 6.9498,
    source_name: "Collectif coopératif",
    source_url:  "",
    image_url:   "",
    body: <<~MD,
      ### Le déclic
      Lutter contre les vitrines vides en centre-ville.

      ### Le projet
      Société coopérative : rachat/gestion de locaux, loyers modérés, animation.

      ### Résultats
      Installation d’artisans, cafés, ateliers : une rue reprend vie.
    MD
    quote: "On a mis nos moyens en commun pour reprendre notre ville."
  },

  # Autres histoires locales (projets commerciaux)
  {
    slug: "seventheen-coffee-luneville",
    title: "SEVENTHÉEN Coffee — Coffee shop (Lunéville)",
    chapo: "Deux reconversions, puis ouverture d'un coffee shop.",
    description: "Café de spécialité, petite restauration, animations.",
    location: "Lunéville",
    latitude: 48.591, longitude: 6.496,
    source_name: "Page officielle",
    source_url:  "/stories/articles/coffee-shop_luneville.pdf",
    image_url:   "https://cdn.website.dish.co/media/5c/2f/2551554/SEVENTHEEN-Coffee-Luneville.jpg",
    body: <<~MD,
      ### Parcours
      Formations barista, torréfaction, ouverture d’un lieu chaleureux.

      ### Leçons
      - Éducation client bienveillante  
      - Carte courte, exécution précise
    MD
    quote: "On sert un café… et une culture."
  },
  {
    slug: "saveurs-exotics-toul",
    title: "Saveurs Exotics — Épicerie antillaise & africaine (Toul)",
    chapo: "Du conseil RH à l'entrepreneuriat local.",
    description: "Épicerie fine, ateliers cuisine, bar à salade.",
    location: "Toul",
    latitude: 48.682, longitude: 5.894,
    source_name: "Site officiel",
    source_url:  "https://www.saveurs-exotics.fr/",
    image_url:   "https://www.saveurs-exotics.fr/wp-content/uploads/2025/06/Slide1-compressed.jpg",
    body: <<~MD,
      ### Le déclic
      Partager des goûts d’enfance et d’ailleurs.

      ### La boutique
      Conseils, paniers découverte, ateliers cuisine.

      ### Impact
      Diversité culinaire + mise en avant de producteurs.
    MD
    quote: "Faire voyager les gens, sans quitter Toul."
  },
  {
    slug: "fred-taxi-saulxures",
    title: "Fred’Taxi — Artisan taxi (Saulxures-lès-Nancy)",
    chapo: "À 48 ans, Frédéric passe de cariste à artisan taxi.",
    description: "Reconversion, carte pro obtenue et création d’entreprise.",
    location: "Saulxures-lès-Nancy",
    latitude: 48.654, longitude: 6.209,
    source_name: "",
    source_url:  "",
    image_url:   "",
    body: <<~MD,
      ### Le métier
      Courses locales, scolaires, médicales. Fiabilité = fidélisation.

      ### Leçons
      - Zone de chalandise claire  
      - Dire non aux courses non rentables
    MD
    quote: "Ce que je vends ? La fiabilité."
  },
  {
    slug: "lecrin-damelevieres",
    title: "L’Écrin Bar & Lounge (Damelevières)",
    chapo: "Ancienne salariée d’Ehpad, elle reprend un bar-lounge.",
    description: "Programmation, scènes ouvertes, partenariats associatifs.",
    location: "Damelevières",
    latitude: 48.573, longitude: 6.346,
    source_name: "L'Est Républicain",
    source_url:  "/stories/articles/lecrin-damelevieres.pdf",
    image_url:   "",
    body: <<~MD,
      ### Coulisses
      Licence, voisinage, sécurité : anticiper & dialoguer.

      ### Leçons
      - La programmation fait la différence  
      - Charte de convivialité = 90 % des soucis évités
    MD
    quote: "Un endroit où l’on se sent bien."
  },
  {
    slug: "madame-bergamote-nancy",
    title: "Madame Bergamote — Salon de thé (Nancy)",
    chapo: "Un salon de thé artisanal près de Stanislas.",
    description: "Pâtisserie maison, boissons chaudes, ateliers créatifs.",
    location: "Nancy",
    latitude: 48.695, longitude: 6.184,
    source_name: "Page officielle",
    source_url:  "https://madame-bergamote-nancy.eatbu.com/?lang=fr",
    image_url:   "https://cdn.website.dish.co/media/5f/a2/7245201/Madame-Bergamote-312987467-105901108988435-4889136544572526137-n-jpg.jpg",
    body: <<~MD,
      ### Leçons
      Fraîcheur, carte courte, régularité d’exécution.
    MD
    quote: "La simplicité précise, c’est un luxe."
  },
  {
    slug: "galapaga-villers",
    title: "GALAPAGA — Concept-store éthique (Villers-lès-Nancy)",
    chapo: "Laure, éducatrice, lance une boutique responsable.",
    description: "Puériculture, jeux, mode, ateliers, Florain.",
    location: "Villers-lès-Nancy",
    latitude: 48.672, longitude: 6.152,
    source_name: "",
    source_url:  "",
    image_url:   "",
    body: <<~MD,
      ### Leçons
      Transparence prix, fiches pédagogiques, SAV soigné.
    MD
    quote: "Mieux acheter, c’est déjà agir."
  },
  {
    slug: "alexs-pastries-vandoeuvre",
    title: "Alex’s Pastries — Pâtisserie (Vandœuvre-lès-Nancy)",
    chapo: "Reconversion : de l’enseignement à la pâtisserie.",
    description: "Sur commande + ateliers à domicile.",
    location: "Vandœuvre-lès-Nancy",
    latitude: 48.656, longitude: 6.176,
    source_name: "Site officiel",
    source_url:  "https://alexloulous.wixsite.com/alexspastries",
    image_url:   "https://static.wixstatic.com/media/d30316_7bde4702681c4fd5ab1446470d45bf88~mv2.jpeg/v1/fill/w_980,h_980,al_c,q_85/Entremets%20vanille%20fruits%20rouges.jpeg",
    body: <<~MD,
      ### Leçons
      Monter en puissance par paliers, photos soignées, partenariats.
    MD
    quote: "Je fabrique peu, mais très bien."
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

  if Story.column_names.include?("quote") && quote.present?
    s.assign_attributes(quote: quote)
  end

  s.save!
end
puts "Seeds -> stories: +#{created_stories} (total: #{Story.count})"

