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

  # ===== FORMATION (CCI & ICN) =====
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
  # ★ ICN Executive MBA (à partir de l’article demandé)
  {
    title: "Executive MBA — se réinventer (ICN Business School)",
    description: add_link("Parcours pour cadres/dirigeants : leadership, stratégie, innovation et soutenance d’un projet de transformation. Compatible activité pro.",
                          "https://www.lasemaine.fr/enseignement-formation/executive-mba-quand-icn-aide-les-cadres-a-se-reinventer/"),
    category: "formation",
    organization: "ICN Business School",
    location: "86 Rue Sergent Blandan, 54000 Nancy",
    time_commitment: "Part-time (18–24 mois)",
    latitude: 48.6829, longitude: 6.1766,
    is_active: true, tags: "executive,mba,leadership,transformation"
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
  # ⚠️ n'assigner QUE les attributs existants sur Opportunity
  allowed = h.slice(:title, :description, :category, :organization, :location, :time_commitment, :latitude, :longitude, :is_active, :tags)
  found.assign_attributes(allowed)
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

# ================== “Belles histoires” (localisées, émojis dans le body) ==================
stories = [
  {
    slug: "caseus-nancy",
    title: "CASEUS — Crèmerie-fromagerie (Nancy)",
    chapo: "Bénédicte, ex-finance à Paris, ouvre une fromagerie en Vieille-Ville pour remettre du goût, du local et du lien au cœur du quotidien.",
    description: "Sélection courte, producteurs suivis, conseil à la coupe et plateaux sur mesure.",
    location: "21 Grande Rue, 54000 Nancy",
    latitude: 48.693, longitude: 6.183,
    source_name: "Site officiel",
    source_url:  "https://caseus-nancy.fr/",
    image_url:   "https://caseus-nancy.fr/ims25/enseigne.png",
    body: <<~MD,
      ### 🌿 Le projet
      **CASEUS**, c’est un comptoir de fromages pensé comme une petite boussole du quotidien. Pas d’étagères qui débordent ni de promesses floues : une **sélection courte** tenue avec amour, des **producteurs suivis** dans le temps, des explications simples pour aider chacun à choisir selon l’instant. On y vient pour un comté bien affiné, un chèvre encore tendre, une tomme qui raconte son alpage — et on repart avec une **histoire** à table. L’idée n’est pas de tout avoir, mais de **bien tenir** ce qu’on propose : régularité, fraîcheur, justesse des prix, petites trouvailles de saison.

      ### 🚶‍♀️ Parcours avant l’ouverture
      Après des années dans la finance, **Bénédicte** avait envie d’un métier où l’on **regarde les gens dans les yeux**. Elle se forme aux gestes de cave, visite des affineurs, apprend la patience des fromages qui vivent. Elle dresse des listes, en rature la moitié, garde le **meilleur rapport goût/prix**. Elle teste des plateaux chez des voisins, corrige les tranches, ajuste la coupe, apprivoise la conservation et les températures. Et surtout, elle s’exerce au **conseil** : écouter les envies, proposer une découverte, donner un accord pain/confiture, expliquer d’où vient ce goût noisette ou ce parfum de fleurs sèches.

      ### 🧀 La vie du lieu
      À CASEUS, on n’est pas intimidé. On peut demander « un fromage qui plaît à tout le monde », « quelque chose de plus **caractère** », « un plateau pour six sans se ruiner ». Le samedi, la file avance au rythme des échanges : un peu de **pédagogie** et beaucoup de **bienveillance**. Les enfants goûtent, les curieux notent, les habitués reviennent pour « le même que la dernière fois ». Bénédicte propose aussi des **plateaux prêts** pour les apéros, avec étiquettes et mini-fiches pour glisser deux mots au moment de servir. Le commerce devient **point d’appui gourmand** en Vieille-Ville, un endroit où le goût et la simplicité se saluent.

      ### 💡 Pourquoi c’est inspirant
      - Une reconversion **incarnée** qui valorise des fermes et des gestes 🐄
      - Le **conseil** comme différence, au-delà du produit 🧑‍🍳
      - Le choix du **peu mais bien**, gage de confiance et de fidélité ✨

      —
      📍 Adresse : 21 Grande Rue, 54000 Nancy
      📸 Crédit photo : CASEUS
      📰 Source : Site officiel
    MD
    quote: "Revenir à Nancy et parler goût chaque jour : c’était le sens qui me manquait."
  },

  {
    slug: "laiterie-de-nancy",
    title: "La Laiterie de Nancy (Nancy)",
    chapo: "Matthieu quitte le salariat pour créer une laiterie urbaine visible depuis la rue : yaourts, fromages frais et transparence totale.",
    description: "Atelier vitré, lait de foin rémunéré au juste prix, pédagogie du goût.",
    location: "6 Rue Saint-Nicolas, 54000 Nancy",
    latitude: 48.689, longitude: 6.187,
    source_name: "Article PDF",
    source_url:  "/stories/articles/laiterie-urbaine.pdf",
    image_url:   "https://static.wixstatic.com/media/9f3674e120564679859a204316cae6a8.jpg/v1/fill/w_250,h_166,al_c,q_90/9f3674e120564679859a204316cae6a8.jpg",
    body: <<~MD,
      ### 🌿 Le projet
      **La Laiterie de Nancy** a quelque chose d’enfantin et de moderne à la fois : on **voit** travailler, on **comprend** ce qu’on mange. Dans l’atelier **vitré**, on fabrique des yaourts, des fromages frais, des desserts lactés avec un lait de foin **payé correctement** aux éleveurs. Les recettes sont courtes, les gestes précis, l’hygiène millimétrée. Point de secret : sur l’ardoise, Matthieu note la température, les temps, les ingrédients. Moins de poudre et de promesses ; **plus de lait, plus de maîtrise**.

      ### 🚶‍♂️ Parcours avant l’ouverture
      Matthieu n’a pas posé un jour un pot de yaourt en vitrine par hasard. Il a **appris**, observé, tâtonné. Formations en micro-transformation, visites d’ateliers, calcul des déperditions, des cadences, de la chaîne du froid. Il a construit un **planning** serré pour produire **juste à temps**, sans stock inutile. Et surtout, il a trouvé son ton : parler simplement de ce qui est compliqué, sans dogme ni posture, avec cette **humilité de fabricant** qui rassure et donne envie.

      ### 🥛 La vie du lieu
      Ici, on passe « voir si c’est sorti », on revient chercher « ceux d’hier, ils étaient incroyables ». Les enfants collent leur nez à la vitre, posent mille questions. Les écoles visitent ; on goûte, on sent, on apprend. Les habitants suivent les **saisons** et les essais — un peu plus fermes, un peu plus onctueux ? Chaque lot devient une **conversation** avec le quartier. Et petit à petit, la laiterie s’installe comme une évidence : le **frais** a un visage, une adresse, un prénom.

      ### 💡 Pourquoi c’est inspirant
      - La **transparence** comme promesse tenue 🪟
      - Des produits **ultra-frais** qui racontent une filière locale 🐄
      - Une **pédagogie douce** qui redonne du sens à l’alimentation 🧑‍🏫

      —
      📍 Adresse : 6 Rue Saint-Nicolas, 54000 Nancy
      📸 Crédit photo : Laiterie de Nancy
      📰 Source : Article PDF
    MD
    quote: "Que chacun sache d’où vient le lait et qui on rémunère."
  },

  {
    slug: "madame-bergamote-nancy",
    title: "Madame Bergamote — Salon de thé (Nancy)",
    chapo: "Un salon de thé artisanal près de Stanislas : pâtisseries fines, thés choisis et accueil soigné.",
    description: "Recettes maison, ateliers créatifs, ambiance douce et régulière.",
    location: "3 Grande Rue, 54000 Nancy",
    latitude: 48.695, longitude: 6.184,
    source_name: "Page officielle",
    source_url:  "https://madame-bergamote-nancy.eatbu.com/?lang=fr",
    image_url:   "https://cdn.website.dish.co/media/5f/a2/7245201/Madame-Bergamote-312987467-105901108988435-4889136544572526137-n-jpg.jpg",
    body: <<~MD,
      ### 🌿 Le projet
      **Madame Bergamote**, c’est une parenthèse lumineuse à deux pas de la place Stanislas. On y entre pour un **thé fumant** ou une tarte de saison, on y reste pour l’**accueil** et l’odeur de beurre qui sort du four. Tout est **fait maison**, sans esbroufe : une carte courte qui tient ses promesses, un soin particulier pour la régularité, et ce goût de reviens-y qui crée des **habitudes**.

      ### 🚶‍♀️ Parcours avant l’ouverture
      Derrière le comptoir, une passionnée passée par la **formation** et des expériences en **restauration/vente**. Elle tient un carnet où s’alignent grammages, températures, temps de repos. Elle **ajuste** ses recettes jusqu’à ce qu’elles tiennent la distance : le samedi de rush comme le mardi pluvieux. Elle apprend la petite logistique des salons de thé : **flux**, vitrine de 11 h, commandes à la journée, et ce geste qui rassure : répondre par le **prénom**.

      ### 🍰 La vie du lieu
      On vient pour un **goûter partagé**, une lecture au calme, un atelier de **pâtisserie** ou d’**aquarelle**. La vitrine suit les saisons : fruits rouges, pistache, agrumes. Les assiettes sont **généreuses**, les prix **raisonnables**, l’ambiance **douce**. Ce n’est pas spectaculaire, c’est **tenu**. Et c’est précisément ce qui fidélise : savoir ce que l’on va trouver, et que ce sera **bon**.

      ### 💡 Pourquoi c’est inspirant
      - Une reconversion portée par la **patience** et la **précision** 🧁
      - Le **fait-maison** comme promesse simple et tenue ✨
      - Un commerce d’**accueil** qui tisse une communauté

      —
      📍 Adresse : 3 Grande Rue, 54000 Nancy
      📸 Crédit photo : Madame Bergamote
      📰 Source : Page officielle
    MD
    quote: "La simplicité, quand elle est précise, devient un vrai luxe."
  },

  {
    slug: "galapaga-villers",
    title: "GALAPAGA — Concept-store éthique (Villers-lès-Nancy)",
    chapo: "Laure, éducatrice de jeunes enfants, lance une boutique joyeuse et responsable : écologie, pédagogie, bienveillance.",
    description: "Puériculture, jeux, mode éthique, ateliers parentaux ; partenaire de la monnaie locale Florain.",
    location: "34 Boulevard de Baudricourt, 54600 Villers-lès-Nancy",
    latitude: 48.672, longitude: 6.152,
    source_name: "L’Est Républicain — commerce local",
    source_url: "/stories/articles/galapaga.pdf",
    image_url: "",
    body: <<~MD,
      ### 🌿 Le projet
      **GALAPAGA** ressemble à son nom : doux, coloré, **posé**. Laure y rassemble des **marques responsables** (puériculture, jeux, mode), choisies pour leurs matériaux, leur durabilité, leur **bon sens**. La boutique n’est pas un défilé d’objets : c’est un **parcours**. On touche, on comprend, on achète **mieux**. Et régulièrement, on se retrouve pour des **ateliers parents-enfants** où l’on parle usage, réparation, tri, sans donner de leçon.

      ### 👣 Parcours avant l’ouverture
      Ancienne **éducatrice de jeunes enfants**, Laure voulait un commerce **pédagogique**. Elle crée des **fiches claires** (d’où vient la matière ? comment ça vieillit ?), prépare des démonstrations, et adhère à la monnaie locale **Florain** pour **ancrer** l’économie dans le territoire. Elle apprend la vie d’une petite boutique : passer commande sans sur-stocker, raconter les produits, **accueillir les questions**.

      ### 🧩 La vie du lieu
      Chez GALAPAGA, on peut venir « juste pour comprendre ». On essaie un **portage**, on répare un petit **jouet**, on troque un **vêtement** encore bon. L’ambiance est **bienveillante**, les prix **explicites**, les retours **écoutés**. Peu à peu, la boutique devient un **tiers-lieu léger**, un point de rendez-vous pour celles et ceux qui veulent consommer **mieux** sans se compliquer la vie.

      ### 💡 Pourquoi c’est inspirant
      - La **pédagogie** au cœur de l’expérience d’achat
      - Une économie **locale et circulaire** encouragée au quotidien
      - Un commerce qui **donne envie d’agir** simplement

      —
      📍 Adresse : 34 Boulevard de Baudricourt, 54600 Villers-lès-Nancy
      📰 Source : *L’Est Républicain*
    MD
    quote: "Mieux acheter, c’est déjà agir."
  },

  {
    slug: "miss-cookies-nancy",
    title: "Miss Cookies Coffee — Coffee-shop franchisé (Nancy)",
    chapo: "Aude quitte la fonction publique pour se lancer en franchise : un cadre rassurant, un accueil très personnel.",
    description: "Coffee/snacking rue des Ponts, exécution régulière, équipe locale.",
    location: "9 Rue des Ponts, 54000 Nancy",
    latitude: 48.693, longitude: 6.182,
    source_name: "Site officiel",
    source_url:  "https://www.misscookies.com/",
    image_url:   "https://www.misscookies.com/photos/produits-patisseries.jpg",
    body: <<~MD,
      ### 🔄 Le virage
      **Choisir une franchise**, pour Aude, c’est un moyen d’**accélérer** sans partir de zéro : process éprouvés, achats centralisés, formation initiale. Elle garde l’essentiel pour elle : **l’accueil**, la **régularité**, l’**ambiance**. Son café doit être un repère simple, ouvert, **bien tenu**.

      ### 🧰 Parcours avant l’ouverture
      Quitter la fonction publique n’a pas été un caprice. Aude a **visité**, **comparé**, interrogé des franchisés, pris des notes sur les flux, les heures pleines, la gestion des stocks. Elle a validé l’**emplacement**, recruté une **équipe locale**, appris à **lire la journée** (vitrine 11 h, rush 16 h, fermeture douce). Les premières semaines ont servi d’**ajustement** ; puis les rouages se sont posés.

      ### ☕ La vie du lieu
      Le matin, ce sont les **petits-déjeuners** chauds et les cafés à emporter ; l’après-midi, les **cookies** et les pauses réconfort. Aude ajoute sa **touche** : playlists douces, partenariats avec des créateurs du coin, **opérations solidaires**. Rien d’extravagant ; juste la **constance** qui donne envie de revenir.

      ### 💡 Pourquoi c’est inspirant
      - Une reconversion **pragmatique** et assumée
      - Des **process** au service d’un **accueil** très personnel
      - Un commerce **régulier** qui gagne la confiance du quartier

      —
      📍 Adresse : 9 Rue des Ponts, 54000 Nancy
      📸 Crédit photo : Miss Cookies Coffee
      📰 Source : Site officiel
    MD
    quote: "Je voulais entreprendre, mais jamais seule."
  },

  {
    slug: "alexs-pastries-vandoeuvre",
    title: "Alex’s Pastries — Pâtisserie (Vandœuvre-lès-Nancy)",
    chapo: "De l’enseignement à la pâtisserie artisanale : une entreprise gourmande, locale et sur-mesure.",
    description: "Entremets, gâteaux personnalisés, ateliers à domicile et commande en ligne.",
    location: "6 Rue Notre-Dame-des-Pauvres, 54500 Vandœuvre-lès-Nancy",
    latitude: 48.656, longitude: 6.176,
    source_name: "Site & réseaux — Alex’s Pastries",
    source_url: "https://alexloulous.wixsite.com/alexspastries",
    image_url: "https://static.wixstatic.com/media/d30316_7bde4702681c4fd5ab1446470d45bf88~mv2.jpeg/v1/fill/w_980,h_980,al_c,q_85/Entremets%20vanille%20fruits%20rouges.jpeg",
    body: <<~MD,
      ### 🌿 Le projet
      **Alex’s Pastries** fabrique des **entremets soignés** et des gâteaux personnalisés qui racontent une personne, une table, une fête. Le cœur du modèle est simple : **commande** pour éviter le gâchis, **ateliers** pour transmettre. Les recettes sont équilibrées, les décors précis, et les échanges avec les clients font partie de la **création**.

      ### 🎓 Parcours avant l’ouverture
      Ancienne **enseignante**, Alex prépare son **CAP pâtisserie**, enchaîne les **stages**, documente ses essais. Elle se dote d’un **calendrier de production**, d’une prise de **rendez-vous** en ligne, d’un petit kit de **devis** clair. Le bouche-à-oreille fait le reste, avec une promesse tenue : peu, mais **très bien**.

      ### 🎂 La vie du lieu
      Les week-ends, c’est la ronde des **événements** (anniversaires, mariages) ; en semaine, place aux **ateliers** à la maison ou en tiers-lieu, où l’on apprend la mousse qui tient, la ganache qui brille, la poche qui rassure. Les **retours clients** nourrissent les recettes. Alex a trouvé son tempo : un artisanat **joyeux**, précis, et profondément **humain**.

      ### 💡 Pourquoi c’est inspirant
      - Un modèle **agile** et frugal pour se lancer 🍰
      - La progression par **petites itérations** et feedbacks
      - L’exigence artisanale au service de **vraies personnes** ✨

      —
      📍 Adresse : Vandœuvre-lès-Nancy
      📸 Crédit photo : Alex’s Pastries
      📰 Source : Site & réseaux
    MD
    quote: "Je fabrique peu, mais très bien, pour de vraies personnes."
  },

    {
    slug: "saveurs-exotics-toul",
    title: "Saveurs Exotics — Épicerie antillaise & africaine (Toul)",
    chapo: "Du conseil RH à l’entrepreneuriat local : une épicerie qui fait voyager les papilles et rassemble les gens.",
    description: "Produits antillais et africains, bar à salade, ateliers cuisine et conseils personnalisés.",
    location: "9 Rue Pont-des-Cordeliers, 54200 Toul",
    latitude: 48.682, longitude: 5.894,
    source_name: "Site officiel",
    source_url: "https://www.saveurs-exotics.fr/",
    image_url: "https://www.saveurs-exotics.fr/wp-content/uploads/2025/06/Slide1-compressed.jpg",
    body: <<~MD,
      ### 🌿 Le projet
      À Toul, **Saveurs Exotics** met des couleurs et des arômes dans le quotidien. Derrière le comptoir, on trouve une femme passionnée de cuisine et de partage, passée du **conseil en ressources humaines** à l’**entrepreneuriat gourmand**. Son ambition : faire découvrir des **saveurs d’enfance**, valoriser des producteurs méconnus et créer un lieu où l’on vient autant pour **échanger que pour acheter**.

      Sur les étagères, des produits soigneusement choisis : épices des Antilles, condiments africains, boissons artisanales, confitures maison. Chaque référence est sélectionnée pour sa qualité, son histoire et son authenticité. Et parce que la curiosité ouvre l’appétit, le magasin propose aussi un **bar à salade** et des **dégustations thématiques**.

      ### 🚶‍♀️ Parcours avant l’ouverture
      Après plusieurs années dans le monde de la formation, la fondatrice ressent le besoin de **retrouver du concret**. Elle reprend ses racines culinaires, multiplie les salons, échange avec des importateurs et affine ses recettes maison. Étudier les produits, apprendre la gestion d’un stock vivant, comprendre les attentes du public : tout cela devient son **nouvel apprentissage**. Un pari audacieux, mené avec rigueur et enthousiasme.

      ### 🍛 La vie du lieu
      Chaque semaine, le magasin s’anime : **ateliers cuisine**, **soirées dégustation**, playlists créoles et recettes partagées sur un coin de table. Les habitués viennent pour un conseil, un mot, une idée. Ici, on parle aussi bien de **goût que de souvenirs**. En deux ans, l’adresse s’est imposée comme un **point de rencontre** entre cultures et générations.

      ### 💡 Pourquoi c’est inspirant
      - Une reconversion **authentique**, qui fait du commerce un vecteur de lien 💬
      - La **pédagogie** comme ingrédient essentiel de la réussite 🍴
      - Un commerce local qui redonne des **couleurs au centre-ville** 🌈

      —
      📍 Adresse : 9 Rue Pont-des-Cordeliers, 54200 Toul
      📸 Crédit photo : Saveurs Exotics
      📰 Source : Site officiel
    MD
    quote: "Faire voyager les gens, sans quitter Toul."
  },

  {
    slug: "lecrin-damelevieres",
    title: "L’Écrin — Bar & Lounge (Damelevières)",
    chapo: "Ancienne salariée d’EHPAD, elle reprend un bar-lounge et relance la vie du bourg avec une programmation simple et régulière.",
    description: "Carte courte, scènes ouvertes, partenariats associatifs et ambiance chaleureuse.",
    location: "19 Rue de la Libération, 54360 Damelevières",
    latitude: 48.573, longitude: 6.346,
    source_name: "L'Est Républicain (12/09/2025)",
    source_url: "/stories/articles/lecrin-damelevieres.pdf",
    image_url: "",
    body: <<~MD,
      ### 🌿 Le projet
      **L’Écrin** porte bien son nom : un petit lieu convivial niché au cœur de Damelevières, où l’on se sent accueilli dès le seuil franchi. L’ancienne salariée d’EHPAD qui l’a repris voulait un endroit pour **rassembler sans prétention**, un espace de respiration après des années au service des autres. Son idée : un **bar-lounge** où la carte reste courte, les visages familiers, et la musique bien choisie.

      Entre un verre de vin, un café ou une planche apéro, on échange, on rit, on se retrouve. Chaque semaine, l’Écrin propose une **soirée thématique** : karaoké, blind test, concert acoustique ou soirée jeux. Rien d’excessif, mais **tenu, sincère et régulier**. L’énergie du lieu repose sur la simplicité : une lumière douce, une poignée de tables, un sourire franc.

      ### 🚶‍♀️ Parcours avant l’ouverture
      Après quinze ans en maison de retraite, elle décide de **changer de mission** sans changer de valeurs : **prendre soin**. Dossier de licence, formation en gestion, recherche de financement… L’ouverture du bar a été une école de patience. Elle s’entoure de proches, de bénévoles, de voisins, et apprend sur le tas la comptabilité, la communication, les autorisations. Chaque étape devient une **victoire tranquille**.

      ### 🎵 La vie du lieu
      Aujourd’hui, L’Écrin est plus qu’un bar : c’est un **rendez-vous de quartier**. Les jeunes viennent y chanter, les seniors y discutent l’après-midi, les associations locales y trouvent un point d’ancrage pour leurs événements. Les habitants redécouvrent la chaleur d’un commerce de proximité où l’on peut simplement **être bien**.

      ### 💡 Pourquoi c’est inspirant
      - Une **reprise audacieuse** qui prouve qu’on peut changer de vie à tout âge ✨
      - Une **programmation légère** mais constante, au service du lien social 🎶
      - Le **prendre soin** transposé à l’accueil et à la convivialité 🤝

      —
      📍 Adresse : 19 Rue de la Libération, 54360 Damelevières
      📸 Crédit photo : L’Écrin
      📰 Source : *L’Est Républicain* (2025)
    MD
    quote: "Un endroit où l’on se sent bien, tout simplement."
  },

  {
    slug: "fred-taxi-saulxures",
    title: "Fred’Taxi — Artisan taxi (Saulxures-lès-Nancy)",
    chapo: "À 48 ans, Frédéric passe de cariste à artisan taxi : autonomie, service et confiance au quotidien.",
    description: "Transport local, médical, scolaire ; qualité de service et régularité.",
    location: "38 Grande Rue, 54420 Saulxures-lès-Nancy",
    latitude: 48.654, longitude: 6.209,
    source_name: "Témoignage local",
    source_url: "",
    image_url: "",
    body: <<~MD,
      ### 🚕 Le projet
      Après vingt ans passés en entrepôt, **Frédéric** avait besoin d’air et de liberté. Son choix : devenir **artisan taxi**. À première vue, un simple changement de volant. En réalité, une nouvelle manière d’être utile. Aujourd’hui, il transporte des **patients**, des **enfants**, des **habitants isolés**, toujours avec le même soin. Ponctuel, poli, fiable, il est devenu pour beaucoup un **repère discret mais essentiel**.

      ### 🔧 Parcours avant l’ouverture
      Reprendre la route n’a rien d’improvisé : formation, obtention de la **carte professionnelle**, recherche du bon véhicule, création d’une micro-entreprise, conventions avec les caisses de santé. Frédéric apprend tout, seul ou presque, avec l’aide d’anciens du métier. Ce qu’il gagne en paperasse, il le retrouve en **autonomie**. Il connaît ses clients, adapte ses horaires, entretient une **relation de confiance** qui dépasse la simple course.

      ### 🤝 La vie du service
      Dans les villages autour de Nancy, son numéro circule de bouche à oreille. Les gens l’appellent pour un rendez-vous médical, un trajet vers la gare, un retour tardif. Toujours une voix calme au bout du fil, un trajet sûr, un mot gentil. Fred sait écouter, patienter, rassurer. Et c’est peut-être là son vrai métier : **rendre la mobilité humaine**.

      ### 💡 Pourquoi c’est inspirant
      - Une reconversion **sobre et utile** qui recrée du lien de proximité 🛣️
      - Un modèle de **service artisanal** au cœur du quotidien 🚗
      - La preuve que la **fiabilité** peut être une vocation à part entière 💬

      —
      📍 Secteur : Saulxures-lès-Nancy & environs
      📸 Crédit photo : Fred’Taxi
      📰 Source : Témoignages locaux
    MD
    quote: "Ce que je vends ? La fiabilité."
  }
]

# ——— Ajouts “Belles histoires” depuis Destination Nancy (pp.16–17)
[
  {
    slug: "cerfav-vannes-le-chatel",
    title: "CERFAV — Arts verriers (Vannes-le-Châtel)",
    category: "formation",
    chapo: "Un lieu unique où l’on souffle le verre, on apprend, on crée — du premier cœur en duo à la boule de Noël, la magie devient geste.",
    description: "Formations & ateliers grand public (soufflage, fusing), galerie-boutique et expositions autour du verre.",
    location: "Rue du Grippot, 54112 Vannes-le-Châtel",
    latitude: nil, longitude: nil,
    source_name: "Destination Nancy",
    source_url: "/stories/articles/destination-nancy.pdf",
    image_url: "stories/cerfav.jpg",
    body: <<~MD,
      ### 🌿 Le projet
      À Vannes-le-Châtel, le **CERFAV** mélange transmission, création et émerveillement. On y vient pour **voir** le verre prendre forme au bout de la canne, pour **essayer** un premier geste, pour repartir avec une pièce qui a une histoire : la vôtre. Entre ateliers **grand public** (soufflage d’ornements, **fusing** en couleurs) et expositions, le lieu fonctionne comme un **accélérateur d’envies** : il rend le geste verrier accessible, sans rien enlever à sa poésie. :contentReference[oaicite:0]{index=0}

      ### 🚶‍♀️ Parcours & pédagogie
      C’est d’abord un **centre de formation** et de recherche reconnu — mais ici, la pédagogie ne s’arrête pas aux pros. L’équipe a conçu des formats courts **dès 6 ans**, pensés pour que chacun réussisse **en sécurité**, avec un résultat concret (boules de Noël, **cœurs soufflés**, pièces en verre fusionné). L’idée : **apprendre par le faire**, comprendre la chaleur, la gravité, le refroidissement… et regarder la matière vivre sous vos yeux. :contentReference[oaicite:1]{index=1}

      ### 🔥 La vie du lieu
      Les temps forts rythment l’année : ateliers de **Noël** pour souffler sa boule, sessions **Saint-Valentin** pour créer un cœur à deux, découverte du **fusing** pendant l’hiver… La **galerie-boutique** prolonge l’expérience et l’Office de Tourisme métropolitain propose aussi des créations du CERFAV en ville — de quoi offrir local, **beau et durable**. Réservation en ligne, accueil bienveillant, équipe passionnée : on repart avec une pièce et une **étincelle**. :contentReference[oaicite:2]{index=2}

      ### 💡 Pourquoi c’est inspirant
      - Un savoir-faire d’exception rendu **accessible** ✨
      - Des ateliers courts qui **réenchantent** l’apprentissage 🧪
      - Un lien direct entre **créateurs, habitants et visiteurs** 🫶

      —
      📍 Rue du Grippot, Vannes-le-Châtel
      📰 Source : *Destination Nancy*, pp.16 (programmation & ateliers). :contentReference[oaicite:3]{index=3}
    MD
    quote: "Le verre se travaille comme une histoire : souffle, patience… et lumière."
  },

  {
    slug: "le-lupin-atelier-ceramique-nancy",
    title: "Le Lupin — Atelier de céramique (Nancy)",
    category: "formation",
    chapo: "Un atelier familial, des cours et des stages pour apprivoiser la terre — et une box 100 % céramique, pensée à Nancy.",
    description: "Cours, initiations, pratique autonome encadrée, ventes éphémères & abonnement « La Box du Lupin ». ",
    location: "5 Place de la Croix de Bourgogne, 54000 Nancy",
    latitude: nil, longitude: nil,
    source_name: "Destination Nancy",
    source_url: "/stories/articles/destination-nancy.pdf",
    image_url: "stories/le-lupin.jpg",
    body: <<~MD,
      ### 🌿 Le projet
      **Le Lupin** est un atelier de céramique tenu par deux artisans passionnés. C’est un lieu **vivant** plus qu’une vitrine : on y façonne, on y tourne, on y émaille, on y parle de gestes et de temps long. L’équipe propose des **cours** et **initiations**, mais aussi des temps de **pratique autonome** pour continuer à créer **à son rythme**, comme un abonnement à sa propre progression. Des **ventes éphémères** ponctuent l’année : des pièces en grès ou en porcelaine, utiles et durables. :contentReference[oaicite:4]{index=4}

      ### 🎁 Une box qui soutient l’artisanat
      Leur **Box du Lupin** (tous les deux mois) réunit des pièces faites main à Nancy — un concentré d’objets **utiles, sobres, touchants**, livrés à domicile. C’est une excellente porte d’entrée pour qui veut **offrir local** ou s’équiper autrement, en apprenant à reconnaître la **qualité d’une cuisson**, d’un émail, d’un bord bien tourné. :contentReference[oaicite:5]{index=5}

      ### 🏺 La vie du lieu
      L’atelier est ouvert **du lundi au samedi** : cours, **stages**, créneaux d’atelier libre… Les débutants y trouvent une **pédagogie rassurante** (on dédramatise le « raté »), les plus avancés viennent pour l’**exigence des finitions**. On s’y croise, on s’encourage, on compare des terres, on passe dire bonjour lors d’une **vente d’artisans**. Une vraie **communauté** de mains dans la terre. :contentReference[oaicite:6]{index=6}

      ### 💡 Pourquoi c’est inspirant
      - Une **école du geste** chaleureuse, pour tous niveaux 👐
      - Un modèle mêlant **formation & diffusion** locale 📦
      - Le temps long de l’artisanat, rendu **désirable** au quotidien ⏳

      —
      📍 5 place de la Croix de Bourgogne, Nancy
      📰 Source : *Destination Nancy*, p.17 (atelier & Box du Lupin). :contentReference[oaicite:7]{index=7}
    MD
    quote: "Apprendre la terre, c’est apprendre la patience… et la joie du concret."
  },

  {
    slug: "club-sandwich-illustration-nancy",
    title: "Club Sandwich — Atelier-boutique d’illustrations (Nancy)",
    category: "rencontres",
    chapo: "Deux illustratrices, une vitrine colorée et des rendez-vous réguliers pour faire vibrer l’imaginaire — du dessin à la sérigraphie.",
    description: "Boutique-atelier, sérigraphies, objets illustrés, événements & rencontres avec des artistes locaux.",
    location: "21 Rue de la Source, 54000 Nancy",
    latitude: nil, longitude: nil,
    source_name: "Destination Nancy",
    source_url: "/stories/articles/destination-nancy.pdf",
    image_url: "stories/club-sandwich.jpg",
    body: <<~MD,
      ### 🌿 Le projet
      **Club Sandwich** (ex-Cueillir) est la boutique-atelier de deux illustratrices, **Chloé Revel** et **Cami Berni**. Leur univers mêle **Art nouveau**, faune & flore, **Japon** et estampe — le tout décliné en **illustrations et sérigraphies** qui accrochent l’œil et le sourire. On entre pour une affiche, on reste pour la **conversation** sur un papier, une encre, une trame, un cadrage. :contentReference[oaicite:8]{index=8}

      ### ✍️ Parcours & engagement
      Investies dans le tissu **associatif et culturel**, elles conçoivent la boutique comme un **lieu de circulation** : accueillir d’autres illustrateurs, organiser des **temps forts**, provoquer des rencontres. On peut aussi **commander une illustration** personnalisée — une façon joyeuse de célébrer une histoire, un lieu, une passion. :contentReference[oaicite:9]{index=9}

      ### 🎨 La vie du lieu
      Ouverte **du mercredi au samedi (14h–18h)**, la boutique est un point de ralliement pour les curieux, les étudiants, les **amoureux d’objets imprimés**. Entre **petites séries**, pochettes, pins et pièces chinées, chacun trouve de quoi **offrir local** sans se ruiner. Et comme les vitrines changent au fil des saisons, **revenir** est toujours une bonne idée. :contentReference[oaicite:10]{index=10}

      ### 💡 Pourquoi c’est inspirant
      - Un **atelier-boutique** qui crée de la **rencontre** 🤝
      - L’illustration **vivante**, entre artisanat et culture populaire 🖼️
      - Des **commandes sur mesure** qui racontent les gens 💬

      —
      📍 21 rue de la Source, Nancy
      📰 Source : *Destination Nancy*, p.17 (profil & horaires). :contentReference[oaicite:11]{index=11}
    MD
    quote: "Donner à voir, et donner envie de créer."
  },
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
