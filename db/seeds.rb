# db/seeds.rb
# Idempotent, compatible Heroku (Postgres)

# ======================= Helpers =======================
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

# URL fingerprintée d’un asset (production Heroku)
def asset_url(path)
  ActionController::Base.helpers.asset_path(path)
rescue
  "/assets/#{path}"
end

def add_link(desc, url)
  [desc.to_s.strip, "\n\n🔗 En savoir plus : #{url}"].join
end

# =================== Données de base ===================
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

# ================== Opportunités ==================
records = []

# — Paris (maquette pour densifier la carte)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n: 14, category: "benevolat",    orgs: orgs_paris, titles: benevolat_titles)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n: 10, category: "formation",    orgs: orgs_paris, titles: formation_titles)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n:  8, category: "rencontres",   orgs: orgs_paris, titles: rencontres_titles)
records += mk(loc: "Paris", lat: paris[:lat], lon: paris[:lon], n:  6, category: "entreprendre", orgs: orgs_paris, titles: entreprendre_titles)

# — Nancy : entrées réelles & actionnables
nancy_real = [
  # ===== ENTREPRENDRE (CCI…) =====
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

  # ===== FORMATION (CCI) =====
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

  # ===== RENCONTRES =====
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

  # ===== BÉNÉVOLAT =====
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
    title: "Bénévolat boutique & recyclerie",
    description: add_link("Accueil, caisse, réassort, tri. Faire vivre une économie circulaire locale.",
                          "https://emmaus-france.org"),
    category: "benevolat",
    organization: "Emmaüs — Agglo de Nancy",
    location: "Heillecourt / agglomération nancéienne",
    time_commitment: "Ponctuel ou régulier",
    latitude: 48.654, longitude: 6.183,
    is_active: true, tags: "recyclerie,réemploi,accueil"
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

# — Axe Nancy ⇄ Saint-Dié : opportunités enrichies (développées)
# — Axe Nancy ⇄ Saint-Dié : opportunités enrichies (développées)
vosges_corridor = [
  {
    title: "SEVENTHÉEN Coffee — ateliers découverte",
    description: <<~MD.strip,
      ☕ Découvrir le **café de spécialité** à Lunéville.

      **Ce que tu peux faire**
      - Participer à un atelier : mouture, méthode douce (V60, Chemex), latte-art
      - Filer un coup de main sur une **soirée** (service léger, accueil, encaissement simple)
      - Proposer une **rencontre pro** : freelances, étudiants, créatifs (format 1 h)

      **Pourquoi c’est intéressant**
      - Tu apprends un vrai **savoir-faire sensoriel** (fraîcheur, extraction)
      - Tu **rencontres du monde** et tu animes le centre-ville
      - Format **facile à répliquer** (1–2 h), idéal pour se lancer dans l’événementiel
    MD
    category: "rencontres",
    organization: "SEVENTHÉEN Coffee",
    location: "Lunéville (rue de la République)",
    time_commitment: "Ateliers 1–2 h, soirées ponctuelles",
    latitude: 48.591, longitude: 6.496,
    is_active: true, tags: "atelier,café,communauté"
  },
  {
    title: "Baccarat — Atelier vitrail & découverte du verre",
    description: <<~MD.strip,
      🧪 Initie-toi aux bases du **vitrail** et des découpes de verre (sécurité + gestes).

      **Ce que tu peux faire**
      - Atelier d’initiation **2–3 h** (découpe, sertissage, assemblage simple)
      - Visite d’atelier, **rencontre d’artisans** du Pays du Cristal
      - Proposer une **animation jeunesse** ou une mini **portes ouvertes**

      **Pourquoi c’est intéressant**
      - **Ultra concret** : tu repars avec une petite pièce
      - Tu te fais un **réseau d’artisans** emblématiques de la vallée
      - Idéal pour tester un **savoir-faire manuel** avant une formation longue
    MD
    category: "formation",
    organization: "Atelier associatif du Pays du Cristal",
    location: "Baccarat",
    time_commitment: "2–3 h (samedi AM/PM)",
    latitude: 48.450, longitude: 6.742,
    is_active: true, tags: "artisanat,verre,initiation"
  },
  {
    title: "Raon-l’Étape — Repair & Low-tech au tiers-lieu",
    description: <<~MD.strip,
      🔧 Soirée **réparation** et démonstrations **low-tech**.

      **Ce que tu peux faire**
      - Tenir l’**accueil** et aiguiller les participants
      - Apprendre les bases (petite électricité, affûtage, couture, colle/époxy)
      - Animer un **mini-atelier** (entretien vélo, petites soudures, diagnostic)

      **Pourquoi c’est intéressant**
      - Tu **apprends en faisant** et tu rends service
      - Tu tisses un **réseau local** bricoleurs ↔︎ habitants
      - Tu découvres la **sobriété pratique** (réparer plutôt que jeter)
    MD
    category: "benevolat",
    organization: "Tiers-lieu Vallée de la Plaine",
    location: "Raon-l’Étape",
    time_commitment: "Mensuel (soirée 3 h)",
    latitude: 48.404, longitude: 6.838,
    is_active: true, tags: "repair,lowtech,entraide"
  },
  {
    title: "Étival-Clairefontaine — Atelier micro-entreprise express",
    description: <<~MD.strip,
      💼 Comprendre les **bases de la micro-entreprise** : statuts, obligations, prix de revient, premiers clients.

      **Ce que tu peux faire**
      - Venir avec une idée et repartir avec un **plan 30 jours**
      - Répartir les premières actions : **facture/devis** (modèles), **script d’appel**, **mail de prospection**
      - Poser toutes tes questions (TVA, ARE/ACRE, plafond, compte pro…)

      **Pourquoi c’est intéressant**
      - Format **très opérationnel** pour déclencher un premier **CA** local
      - Tu repars avec un **kit prêt-à-l’emploi** (templates + check-list)
      - Tu rencontres d’autres personnes **au même stade**
    MD
    category: "entreprendre",
    organization: "Com’Com de la Plaine",
    location: "Étival-Clairefontaine",
    time_commitment: "Atelier 2 h",
    latitude: 48.407, longitude: 6.882,
    is_active: true, tags: "création,pricing,prospection"
  },
  {
    title: "Saint-Dié-des-Vosges — Club projet (bénévolat utile)",
    description: <<~MD.strip,
      ❤️ **Club d’entraide** où chacun apporte 1 ressource (compétence, contact, temps) pour **faire avancer** les projets des autres.

      **Ce que tu peux faire**
      - Présenter ton besoin (**5 min**) : “je cherche 5 retours clients”, “je dois faire un devis…”
      - Proposer un **coup de main express** (20–30 min) pendant la session
      - Rejoindre un **mini-commando** : créer un formulaire, faire 10 appels, rédiger un mail-type

      **Pourquoi c’est intéressant**
      - Tu **gagnes en réseau** (liens concrets)
      - Tu avances **tout de suite** (action pendant la séance)
      - Tu aides des **projets locaux** qui ont du sens
    MD
    category: "rencontres",
    organization: "Communauté Déclic Vosges",
    location: "Saint-Dié-des-Vosges",
    time_commitment: "Toutes les 2 semaines, 1 h 30",
    latitude: 48.285, longitude: 6.949,
    is_active: true, tags: "entraide,réseau,accélération"
  },
  {
    title: "Saint-Nicolas-de-Port — Reprise de bar alternatif (diagnostic)",
    description: <<~MD.strip,
      🍻 **Étude de reprise** d’un petit bar alternatif (clientèle locale, mini-prog concerts/stand-up).

      **Ce que tu peux faire**
      - Visite + **check-list** : licences, voisinage, sécurité, accessibilité, travaux, assurances
      - **Tester une soirée** pilote (format réduit) pour jauger le potentiel
      - Chiffrer un **P&L réaliste** (loyer, marge, masse salariale, billetterie)

      **Pourquoi c’est intéressant**
      - Idéal si tu veux **entreprendre avec un lieu vivant** à taille humaine
      - Tu apprends à **évaluer un fonds** (risques/opportunités) avant de signer
      - Tu repars avec une **feuille de route** claire
    MD
    category: "entreprendre",
    organization: "Accompagnement Déclic",
    location: "Saint-Nicolas-de-Port",
    time_commitment: "2 rendez-vous (2×2 h) + 1 soirée test",
    latitude: 48.634, longitude: 6.300,
    is_active: true, tags: "reprise,événementiel,gestion"
  }
]

records += vosges_corridor


# — Quelques autres villes (léger bruit pour la carte)
{ "Lyon" => [45.7640, 4.8357], "Rennes" => [48.1173, -1.6778], "Lille" => [50.6292, 3.0573] }.each do |city, (lat, lon)|
  records += mk(loc: city, lat: lat, lon: lon, n: 2, category: "rencontres", orgs: orgs_common, titles: rencontres_titles, city_label: city)
end

# ================== Insertion idempotente (Opportunities) ==================
created_opps = 0
records.each do |h|
  next unless h[:latitude] && h[:longitude]
  found = Opportunity.find_or_initialize_by(title: h[:title], organization: h[:organization], location: h[:location])
  found.assign_attributes(h)
  created_opps += 1 if found.new_record?
  found.save!
end
puts "Seeds -> opportunities: +#{created_opps} (total: #{Opportunity.count})"

# ================== Témoignages ==================
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

# ================== “Belles histoires” (localisées) ==================
stories = [
  # — Nancy et agglo (déjà existantes)
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

      ### Les obstacles
      Financement des équipements, normes d’hygiène, gestion des pics de saison.

      ### Impact local
      Commerce de proximité, dégustations, valorisation des fermes partenaires.
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
      Entreprendre utile, local, visible depuis la rue.

      ### Le projet
      Atelier vitré : yaourts, fromages frais, desserts lactés. Lait de foin payé au juste prix, transparence recettes.

      ### Ce que ça change
      Produits ultra-frais, lien aux éleveurs, pédagogie auprès des écoles.
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
    source_url:  "/stories/articles/coffee-shop_luneville.pdf",
    image_url:   "https://cdn.website.dish.co/media/5c/2f/2551554/SEVENTHEEN-Coffee-Luneville.jpg",
    body: <<~MD,
      ### Le parcours
      Formation barista, rencontres torréfacteurs, ouverture en cœur de ville.

      ### L’expérience
      Origines précises, méthodes douces, ateliers d’initiation.

      ### Les défis
      Flux du midi, constance d’extraction, pédagogie client.
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
      Entrepreneuriat à taille humaine, valoriser des goûts d’enfance.

      ### La boutique
      Références de qualité, ateliers cuisine, bar à salade.

      ### L’impact
      Découverte culinaire, mise en avant producteurs partenaires.
    MD
    quote: "Faire voyager les gens, sans quitter Toul."
  },
  {
    slug: "fred-taxi-saulxures",
    title: "Fred’Taxi — Artisan taxi (Saulxures-lès-Nancy)",
    chapo: "À 48 ans, Frédéric passe de cariste à artisan taxi.",
    description: "Reconversion, carte pro et création d’entreprise.",
    location: "38 Grande Rue, 54420 Saulxures-lès-Nancy",
    latitude: 48.654, longitude: 6.209,
    source_name: "",
    source_url:  "",
    image_url:   "",
    body: <<~MD,
      ### Le déclic
      Chercher plus d’autonomie et de contact client.

      ### Le métier
      Courses locales, médicales, scolaires. Outils simples pour planifier.

      ### Les réalités
      Horaires, assurance, relationnel : constance et fiabilité.
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
      Créer un lieu sûr, chaleureux, animé.

      ### La proposition
      Carte courte, scènes ouvertes, partenariats associatifs.

      ### Les coulisses
      Licence, voisinage, sécurité, com’ régulière.
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
      Pâtisserie artisanale + accueil soigné = lieu de rendez-vous.

      ### L’expérience
      Production quotidienne, carte courte, ateliers.

      ### Les défis
      Flux week-end, gestion des coûts matière, précommandes.
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
      Vendre utile et durable, avec pédagogie.

      ### Le concept
      Sélection éthique, ateliers parents-enfants, monnaie locale.

      ### Les clés
      Transparence prix, fiches pédagogiques, SAV soigné.
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
      Utiliser le cadre franchise pour aller vite et se concentrer sur l’exécution.

      ### Le quotidien
      Qualité constante, recrutement local, saisonnalité.

      ### Leçon
      Les process sont un support, l’accueil fait la différence.
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
      CAP pâtisserie, commandes locales, ateliers.

      ### Signature
      Entremets soignés, options personnalisées, carnet en ligne.

      ### Montée en puissance
      Retours clients, partenariats, lots vitrines.
    MD
    quote: "Je fabrique peu, mais très bien, pour de vraies personnes."
  },

  # — 3 histoires sourcées L’Est Républicain (axe Nancy ⇄ Saint-Dié)
  {
    slug: "seventheen-coffee-luneville-er",
    title: "SEVENTHÉEN Coffee (Lunéville) — Un coffee shop de spécialité en cœur de ville",
    chapo: "Deux reconversions aboutissent à l’ouverture d’un coffee shop de spécialité rue de la République.",
    description: "Café de spécialité, petite restauration, ateliers d’initiation : un lieu qui anime Lunéville.",
    location: "57 Rue de la République, 54300 Lunéville",
    latitude: 48.591, longitude: 6.496,
    source_name: "L’Est Républicain",
    source_url:  "https://www.estrepublicain.fr/edition-luneville/2024/11/25/seventheen-coffee-un-coffee-shop-rue-de-la-republique",
    image_url:   "",
    body: <<~MD,
      ### Le déclic
      Après des parcours pros différents, les fondateurs tombent amoureux du café de spécialité.

      ### Le projet
      Espresso constant, méthodes douces, **ateliers découverte** ouverts à tous.

      ### Pourquoi c’est inspirant
      Une adresse qui **réveille le centre-ville** et crée des habitudes.
    MD
  },
  {
    slug: "pierre-percee-plein-air-relance-er",
    title: "Pierre-Percée (54) — Parier sur le plein air pour relancer un village",
    chapo: "Investir pour monter en gamme et faire revenir les visiteurs autour du lac.",
    description: "Hébergements et activités de nature comme levier de redynamisation locale.",
    location: "54540 Pierre-Percée",
    latitude: 48.498, longitude: 6.912,
    source_name: "L’Est Républicain",
    source_url:  "https://www.estrepublicain.fr/economie/2025/01/24/pierre-percee-veut-monter-en-gamme-pour-seduir-les-visiteurs",
    image_url:   "",
    body: <<~MD,
      ### Le déclic
      Capitaliser sur le lac et les activités outdoor.

      ### Le projet
      Mise à niveau des équipements, meilleure **expérience visiteur**.

      ### Pourquoi c’est inspirant
      Vision territoriale concrète avec retombées locales.
    MD
  },
  {
    slug: "le-pas-sage-nancy-er",
    title: "Le Pas Sage (Nancy) — La constance d’une cuisine simple et précise",
    chapo: "Dans le faubourg des Trois-Maisons, une adresse qui a trouvé son rythme.",
    description: "Cuisine courte, produits frais et saison, exécution précise.",
    location: "Quartier des Trois-Maisons, 54000 Nancy",
    latitude: 48.701, longitude: 6.177,
    source_name: "L’Est Républicain",
    source_url:  "https://www.estrepublicain.fr/economie/2024/10/26/le-pas-sage-soigne-les-produits-frais-et-les-met-en-scene",
    image_url:   "",
    body: <<~MD,
      ### Le déclic
      Travailler **court, frais, de saison** et viser la régularité.

      ### Le projet
      Carte ramassée, exécution précise, renouvellement saisonnier.

      ### Pourquoi c’est inspirant
      Un restaurant de quartier peut **tenir la distance** sans sur-promettre.
    MD
  }
]

# Insertion idempotente (Stories)
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

  s.assign_attributes(quote: quote) if s.respond_to?(:quote=) && quote.present?
  s.save!
end
puts "Seeds -> stories: +#{created_stories} (total: #{Story.count})"

