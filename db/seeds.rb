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

# Banque d’images par catégorie (illustratives, libres/Unsplash)
CAT_IMAGES = {
  "benevolat"    => "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1200&auto=format&fit=crop",
  "formation"    => "https://images.unsplash.com/photo-1513258496099-48168024aec0?q=80&w=1200&auto=format&fit=crop",
  "rencontres"   => "https://images.unsplash.com/photo-1558222217-0d77a6d3b3d1?q=80&w=1200&auto=format&fit=crop",
  "entreprendre" => "https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=1200&auto=format&fit=crop",
  "default"      => "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1200&auto=format&fit=crop"
}.freeze

def image_for(category)
  CAT_IMAGES[category.to_s] || CAT_IMAGES["default"]
end

# Texte “quand ?” générique durable dans le temps
def next_when_text(fallback: "Créneaux réguliers — inscription en ligne")
  pool = [
    "Prochaine session : **jeudi 13 novembre 2025, 14:00–17:00**",
    "Tous les **mardis** à **18:30** (dès **novembre 2025**)",
    "Un **samedi par mois**, 9:30–12:30 (nov.–déc. 2025)",
    "Cycle **novembre–décembre 2025**, horaires communiqués après inscription",
    "Créneau **hebdomadaire** : jeudi 18:30–20:00 (à partir de nov. 2025)",
    "Format **2–4 h** : dates à venir (nov.–déc. 2025)"
  ]
  pool.sample || fallback
end

def mk(loc:, lat:, lon:, n:, category:, orgs:, titles:, city_label: nil)
  n.times.map do
    t = titles.sample
    o = orgs.sample
    la, lo = jitter(lat, lon, 2.5)
    when_line = next_when_text
    body = [
      "![Illustration](#{image_for(category)})",
      "",
      "### À quoi ça ressemble ?",
      "💡 **#{t}** près de chez toi. Ambiance conviviale, apprentissages concrets et impact local immédiat.",
      "",
      "🗓️ **Quand ?** #{when_line}",
      "",
      "👉 **Ce que tu feras** : participation active, accueil bienveillant, explications claires pas-à-pas."
    ].join("\n")

    {
      title: t,
      description: body,
      category: category,
      organization: o,
      location: city_label || loc,
      time_commitment: ["Mardi 18:30–20:00", "Jeudi 14:00–17:00", "Samedi 9:30–12:30", "Ponctuel (2–3 h)", "Mensuel (soirée)"].sample,
      latitude: la.round(6),
      longitude: lo.round(6),
      is_active: true,
      tags: %w[accueil débutant convivial réseau impact].sample(3).join(", "),
      image_url: image_for(category)
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

def with_illustration_and_when(category:, base_desc:, link: nil, when_line: nil)
  parts = []
  parts << "![Illustration](#{image_for(category)})"
  parts << ""
  parts << "### À quoi ça ressemble ?"
  parts << base_desc.strip
  parts << ""
  parts << "🗓️ **Quand ?** #{(when_line || next_when_text)}"
  parts << ""
  parts << "👉 **Ce que tu feras** : participation active, accueil bienveillant, explications claires pas-à-pas."
  parts << ""
  parts << "🔗 **En savoir plus** : #{link}" if link.present?
  parts.join("\n")
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

# — Nancy : entrées réelles & actionnables (image + “quand ?” explicite)
nancy_real = [
  # ===== ENTREPRENDRE (CCI…) =====
  {
    title: "Atelier — Construire son Business Plan",
    description: with_illustration_and_when(
      category: "entreprendre",
      base_desc: "CCI Grand Nancy : méthodologie, trame financière, hypothèses clés. Conseils personnalisés pour pitcher et convaincre.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Jeudi 13 novembre 2025, 14:00–17:00"
    ),
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Jeudi 13/11/2025, 14:00–17:00",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "business plan,financement,atelier",
    image_url: "https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Permanence création d’entreprise (sur RDV)",
    description: with_illustration_and_when(
      category: "entreprendre",
      base_desc: "Entretien individuel : statut, aides, étapes de la création. Orientation vers partenaires (BPI, CMA, réseaux).",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Chaque mardi (dès nov. 2025), 09:30–12:00 — sur rendez-vous"
    ),
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Hebdomadaire — sur rendez-vous",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "diagnostic,statuts,accompagnement",
    image_url: "https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Afterwork Entrepreneurs Nancy",
    description: with_illustration_and_when(
      category: "entreprendre",
      base_desc: "Rencontres entre porteurs de projet, mentors, experts locaux. Pitches libres, retours d’expérience, réseautage.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Jeudi 27 novembre 2025, 18:30–20:30"
    ),
    category: "entreprendre",
    organization: "Réseau local (CCI & partenaires)",
    location: "Centre-ville, 54000 Nancy",
    time_commitment: "Mensuel, 18:30–20:30",
    latitude: 48.6918, longitude: 6.1837,
    is_active: true, tags: "réseau,pitch,mentorat",
    image_url: "https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Atelier — Financer son projet",
    description: with_illustration_and_when(
      category: "entreprendre",
      base_desc: "Panorama des financements : prêts, subventions, love money, dispositifs région. Préparer son dossier et son prévisionnel.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Vendredi 28 novembre 2025, 09:30–12:00"
    ),
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Vendredi 28/11/2025, 09:30–12:00",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "financement,bpi,subventions",
    image_url: "https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Mentorat entrepreneur·e — rendez-vous découverte",
    description: with_illustration_and_when(
      category: "entreprendre",
      base_desc: "Matching avec mentors (stratégie, juridique, produit). Objectif : clarifier la feuille de route 90 jours.",
      link: "https://communs-entrepreneurs.fr",
      when_line: "Entretiens continus — créneaux nov.–déc. 2025"
    ),
    category: "entreprendre",
    organization: "Communs d’entrepreneurs Nancy",
    location: "Nancy & Métropole",
    time_commitment: "Sur candidature",
    latitude: 48.692, longitude: 6.184,
    is_active: true, tags: "mentorat,roadmap,coaching",
    image_url: "https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=1200&auto=format&fit=crop"
  },

  # ===== FORMATION (CCI & ICN) =====
  {
    title: "Atelier Pitch & Storytelling",
    description: with_illustration_and_when(
      category: "formation",
      base_desc: "Structurer un pitch clair et mémorable : problème, solution, traction. Exercices filmés + feedback.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Mercredi 19 novembre 2025, 14:00–17:00"
    ),
    category: "formation",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Mercredi 19/11/2025, 14:00–17:00",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "pitch,communication,atelier",
    image_url: "https://images.unsplash.com/photo-1513258496099-48168024aec0?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Matinale Numérique — TPE/PME",
    description: with_illustration_and_when(
      category: "formation",
      base_desc: "Référencement local, réseaux sociaux, outils no-code. Cas pratiques d’entreprises du territoire.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Mardi 18 novembre 2025, 08:30–10:00"
    ),
    category: "formation",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Mensuel, 08:30–10:00",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "numérique,seo,no-code",
    image_url: "https://images.unsplash.com/photo-1513258496099-48168024aec0?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Découvrir la méthodologie HACCP (restauration)",
    description: with_illustration_and_when(
      category: "formation",
      base_desc: "Sensibilisation aux bonnes pratiques d’hygiène et aux points critiques — prérequis avant ouverture.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Sessions bimensuelles — prochains créneaux nov.–déc. 2025"
    ),
    category: "formation",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Session bimensuelle",
    latitude: 48.6932, longitude: 6.1829,
    is_active: true, tags: "haccp,restauration,hygiène",
    image_url: "https://images.unsplash.com/photo-1513258496099-48168024aec0?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Executive MBA — se réinventer (ICN Business School)",
    description: with_illustration_and_when(
      category: "formation",
      base_desc: "Parcours pour cadres/dirigeants : leadership, stratégie, innovation et soutenance d’un projet de transformation. Compatible activité pro.",
      link: "https://www.lasemaine.fr/enseignement-formation/executive-mba-quand-icn-aide-les-cadres-a-se-reinventer/",
      when_line: "Rentrée de printemps 2026 — candidatures ouvertes dès nov. 2025"
    ),
    category: "formation",
    organization: "ICN Business School",
    location: "86 Rue Sergent Blandan, 54000 Nancy",
    time_commitment: "Part-time (18–24 mois)",
    latitude: 48.6829, longitude: 6.1766,
    is_active: true, tags: "executive,mba,leadership,transformation",
    image_url: "https://images.unsplash.com/photo-1513258496099-48168024aec0?q=80&w=1200&auto=format&fit=crop"
  },

  # ===== RENCONTRES =====
  {
    title: "Café-projets — échanges entre pairs",
    description: with_illustration_and_when(
      category: "rencontres",
      base_desc: "Partage d’avancées, obstacles et ressources. Format court, bienveillant, ouvert aux débutant·es.",
      link: "https://www.grandnancy.eu",
      when_line: "Tous les 15 jours, jeudi 18:30 — prochain : 06 novembre 2025"
    ),
    category: "rencontres",
    organization: "Communauté Déclic Nancy",
    location: "Place Stanislas, 54000 Nancy",
    time_commitment: "Tous les 15 jours, 18:30",
    latitude: 48.6937, longitude: 6.1834,
    is_active: true, tags: "pair-à-pair,entraide,réseau",
    image_url: "https://images.unsplash.com/photo-1558222217-0d77a6d3b3d1?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Visite — Tiers-lieu & fablab",
    description: with_illustration_and_when(
      category: "rencontres",
      base_desc: "Découverte des machines + ateliers à venir. Idéal pour prototyper et rencontrer des makers.",
      link: "https://lafabriquedespossibles.fr",
      when_line: "Samedi 22 novembre 2025, 10:00–12:00"
    ),
    category: "rencontres",
    organization: "La Fabrique des Possibles",
    location: "Nancy",
    time_commitment: "Mensuel",
    latitude: 48.682, longitude: 6.186,
    is_active: true, tags: "tiers-lieu,fablab,prototype",
    image_url: "https://images.unsplash.com/photo-1558222217-0d77a6d3b3d1?q=80&w=1200&auto=format&fit=crop"
  },

  # ===== BÉNÉVOLAT =====
  {
    title: "Repair Café — accueil & logistique",
    description: with_illustration_and_when(
      category: "benevolat",
      base_desc: "Accueil du public, orientation, aide à la tenue du stand. Ambiance conviviale, sensibilisation anti-gaspillage.",
      link: "https://mjc-bazin.fr",
      when_line: "Samedi 15 novembre 2025, 09:30–12:30"
    ),
    category: "benevolat",
    organization: "MJC Bazin",
    location: "47 Rue Henri Bazin, 54000 Nancy",
    time_commitment: "Mensuel, samedi matin",
    latitude: 48.6848, longitude: 6.1899,
    is_active: true, tags: "réparation,accueil,convivial",
    image_url: "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Atelier couture — coup de main",
    description: with_illustration_and_when(
      category: "benevolat",
      base_desc: "Aider à l’atelier : prise de mesures, préparation du matériel, accompagnement débutant·es.",
      link: "https://mjc-bazin.fr",
      when_line: "Chaque mercredi 17:30–19:30 (nov.–déc. 2025)"
    ),
    category: "benevolat",
    organization: "MJC Bazin",
    location: "47 Rue Henri Bazin, 54000 Nancy",
    time_commitment: "Hebdomadaire",
    latitude: 48.6848, longitude: 6.1899,
    is_active: true, tags: "couture,atelier,pédagogie",
    image_url: "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Distribution alimentaire",
    description: with_illustration_and_when(
      category: "benevolat",
      base_desc: "Renfort sur la distribution, accueil et réassort. Esprit d’équipe, respect et confidentialité.",
      link: "https://www.restosducoeur.org/devenir-benevole/",
      when_line: "Créneaux hebdomadaires (2–3 h), dès novembre 2025"
    ),
    category: "benevolat",
    organization: "Restos du Cœur — Nancy",
    location: "Centre-ville, 54000 Nancy",
    time_commitment: "Hebdomadaire (créneaux 2–3 h)",
    latitude: 48.689, longitude: 6.184,
    is_active: true, tags: "solidarité,logistique,accueil",
    image_url: "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Tri de dons & mise en rayon",
    description: with_illustration_and_when(
      category: "benevolat",
      base_desc: "Collecte, tri, étiquetage. Participer au circuit de revalorisation et à la boutique solidaire.",
      link: "https://www.secourspopulaire.fr",
      when_line: "2–4 h / semaine — créneaux nov.–déc. 2025"
    ),
    category: "benevolat",
    organization: "Secours Populaire — Nancy",
    location: "Nancy",
    time_commitment: "2–4 h / semaine",
    latitude: 48.69, longitude: 6.18,
    is_active: true, tags: "tri,solidarité,boutique",
    image_url: "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Bénévolat boutique & recyclerie",
    description: with_illustration_and_when(
      category: "benevolat",
      base_desc: "Accueil, caisse, réassort, tri. Faire vivre une économie circulaire locale.",
      link: "https://emmaus-france.org",
      when_line: "Créneaux ponctuels et réguliers — dès novembre 2025"
    ),
    category: "benevolat",
    organization: "Emmaüs — Agglo de Nancy",
    location: "Heillecourt / agglomération nancéienne",
    time_commitment: "Ponctuel ou régulier",
    latitude: 48.654, longitude: 6.183,
    is_active: true, tags: "recyclerie,réemploi,accueil",
    image_url: "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Maraude & lien social",
    description: with_illustration_and_when(
      category: "benevolat",
      base_desc: "Aller à la rencontre, distribuer boissons chaudes, orienter vers partenaires. Travail en binôme.",
      link: "https://www.francebenevolat.org",
      when_line: "Soirées (2–3 h) — tournées nov.–déc. 2025"
    ),
    category: "benevolat",
    organization: "Réseau local (associatif)",
    location: "Nancy — différents quartiers",
    time_commitment: "Soirées (2–3 h)",
    latitude: 48.692, longitude: 6.184,
    is_active: true, tags: "maraude,écoute,orientation",
    image_url: "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1200&auto=format&fit=crop"
  }
]

records += nancy_real

# — Axe Nancy ⇄ Saint-Dié : opportunités enrichies (développées)
vosges_corridor = [
  {
    title: "SEVENTHÉEN Coffee — ateliers découverte",
    description: with_illustration_and_when(
      category: "rencontres",
      base_desc: "Découvrir le café de spécialité à Lunéville : mouture, méthode douce (V60, Chemex), latte-art. Aide possible sur une soirée (accueil, encaissement simple) ou organisation de rencontres pros.",
      link: "https://www.instagram.com/seventheen.coffee/",
      when_line: "Ateliers 1–2 h ; soirées ponctuelles — novembre 2025"
    ),
    category: "rencontres",
    organization: "SEVENTHÉEN Coffee",
    location: "Lunéville (rue de la République)",
    time_commitment: "Ateliers 1–2 h, soirées ponctuelles",
    latitude: 48.591, longitude: 6.496,
    is_active: true, tags: "atelier,café,communauté",
    image_url: "https://images.unsplash.com/photo-1558222217-0d77a6d3b3d1?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Baccarat — Atelier vitrail & découverte du verre",
    description: with_illustration_and_when(
      category: "formation",
      base_desc: "Initiation aux bases du vitrail et aux découpes de verre (sécurité + gestes). On repart avec une petite pièce et l’envie de recommencer.",
      link: "https://www.ville-baccarat.com/",
      when_line: "Samedi (2–3 h) — prochains créneaux nov.–déc. 2025"
    ),
    category: "formation",
    organization: "Atelier associatif du Pays du Cristal",
    location: "Baccarat",
    time_commitment: "2–3 h (samedi AM/PM)",
    latitude: 48.450, longitude: 6.742,
    is_active: true, tags: "artisanat,verre,initiation",
    image_url: "https://images.unsplash.com/photo-1513258496099-48168024aec0?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Raon-l’Étape — Repair & Low-tech au tiers-lieu",
    description: with_illustration_and_when(
      category: "benevolat",
      base_desc: "Soirée réparation et démonstrations low-tech. Apprendre en faisant, tisser un réseau local bricoleurs ↔︎ habitants.",
      link: "https://www.facebook.com/tierslieu.valleedelaplaine/",
      when_line: "Mensuel (soirée 3 h) — prochain créneau : fin nov. 2025"
    ),
    category: "benevolat",
    organization: "Tiers-lieu Vallée de la Plaine",
    location: "Raon-l’Étape",
    time_commitment: "Mensuel (soirée 3 h)",
    latitude: 48.404, longitude: 6.838,
    is_active: true, tags: "repair,lowtech,entraide",
    image_url: "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Étival-Clairefontaine — Atelier micro-entreprise express",
    description: with_illustration_and_when(
      category: "entreprendre",
      base_desc: "Bases de la micro-entreprise : statuts, obligations, prix de revient, premiers clients. Repars avec un plan 30 jours.",
      link: "https://www.paysdesabers.fr/",
      when_line: "Atelier 2 h — dates nov.–déc. 2025"
    ),
    category: "entreprendre",
    organization: "Com’Com de la Plaine",
    location: "Étival-Clairefontaine",
    time_commitment: "Atelier 2 h",
    latitude: 48.407, longitude: 6.882,
    is_active: true, tags: "création,pricing,prospection",
    image_url: "https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Saint-Dié-des-Vosges — Club projet (bénévolat utile)",
    description: with_illustration_and_when(
      category: "rencontres",
      base_desc: "Club d’entraide où chacun apporte 1 ressource (compétence, contact, temps) pour faire avancer les projets des autres. Action immédiate pendant la session.",
      link: "https://www.ca-saintdie.fr/",
      when_line: "Toutes les 2 semaines, jeudi 18:30 — prochain : 13 novembre 2025"
    ),
    category: "rencontres",
    organization: "Communauté Déclic Vosges",
    location: "Saint-Dié-des-Vosges",
    time_commitment: "Toutes les 2 semaines, 1 h 30",
    latitude: 48.285, longitude: 6.949,
    is_active: true, tags: "entraide,réseau,accélération",
    image_url: "https://images.unsplash.com/photo-1558222217-0d77a6d3b3d1?q=80&w=1200&auto=format&fit=crop"
  },
  {
    title: "Saint-Nicolas-de-Port — Reprise de bar alternatif (diagnostic)",
    description: with_illustration_and_when(
      category: "entreprendre",
      base_desc: "Étude de reprise d’un petit bar alternatif : visite + check-list (licences, sécurité…), soirée pilote pour jauger le potentiel, P&L réaliste.",
      link: "https://www.saintnicolasdeport.fr/",
      when_line: "2 rendez-vous (2×2 h) + 1 soirée test — nov.–déc. 2025"
    ),
    category: "entreprendre",
    organization: "Accompagnement Déclic",
    location: "Saint-Nicolas-de-Port",
    time_commitment: "2 rendez-vous (2×2 h) + 1 soirée test",
    latitude: 48.634, longitude: 6.300,
    is_active: true, tags: "reprise,événementiel,gestion",
    image_url: "https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=1200&auto=format&fit=crop"
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
  allowed = h.slice(:title, :description, :category, :organization, :location, :time_commitment, :latitude, :longitude, :is_active, :tags, :image_url)
  found.assign_attributes(allowed)
  created_opps += 1 if found.new_record?
  found.save!
end
puts "Seeds -> opportunities: +#{created_opps} (total: #{Opportunity.count})"

# ================== Témoignages ==================
testimonials = [
  { name: "Julien", age: 31, role: "Organisateur d’événements", story: "La communauté m’a permis de créer des rencontres régulières dans mon quartier.", image_url: asset_url("avatars/julien.png") },
  { name: "Emma",  age: 26, role: "Entrepreneuse sociale",      story: "L’accompagnement m’a aidée à lancer mon projet de solidarité.",                image_url: asset_url("avatars/emma.png")   },
  { name: "Thomas",age: 28, role: "Développeur reconverti",      story: "J’ai découvert une formation puis un job qui ont changé ma trajectoire.",   image_url: asset_url("avatars/thomas.png") },
  { name: "Marie", age: 34, role: "Bénévole — Restos du Cœur",   story: "Grâce à Déclic, j’ai trouvé une mission où je me sens utile chaque semaine.", image_url: asset_url("avatars/marie.png") }
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
      CASEUS, c’est un comptoir de fromages pensé comme une petite boussole du quotidien. Pas d’étagères qui débordent ni de promesses floues : une sélection courte tenue avec soin, des producteurs suivis dans le temps, des explications simples pour aider chacun à choisir selon l’instant. On y vient pour un comté bien affiné, un chèvre encore tendre, une tomme qui raconte son alpage — et on repart avec une histoire à table. L’idée n’est pas de tout avoir, mais de bien tenir ce qu’on propose : régularité, fraîcheur, justesse des prix, petites trouvailles de saison.

      ### 🚶‍♀️ Parcours avant l’ouverture
      Après des années dans la finance, Bénédicte voulait un métier où l’on regarde les gens dans les yeux. Formation aux gestes de cave, visites d’affineurs, patience des fromages qui vivent. Listes, essais, plateaux tests chez des voisins, ajustements. Et surtout, pratique du conseil : écouter, proposer une découverte, donner un accord pain/confiture, expliquer d’où vient tel parfum.

      ### 🧀 La vie du lieu
      À CASEUS, on peut demander « un fromage qui plaît à tout le monde », « quelque chose de plus caractère », « un plateau pour six sans se ruiner ». Le samedi, la file avance au rythme des échanges : un peu de pédagogie et beaucoup de bienveillance. Plateaux prêts pour les apéros, étiquettes et mini-fiches pour glisser deux mots au moment de servir. Le commerce devient un point d’appui gourmand en Vieille-Ville.

      ### 💡 Pourquoi c’est inspirant
      - Une reconversion incarnée qui valorise des fermes et des gestes
      - Le conseil comme vraie différence, au-delà du produit
      - Le choix du peu mais bien, gage de confiance et de fidélité

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
      La Laiterie de Nancy a quelque chose d’enfantin et de moderne à la fois : on voit travailler, on comprend ce qu’on mange. Dans l’atelier vitré, on fabrique des yaourts, des fromages frais, des desserts lactés avec un lait de foin payé correctement aux éleveurs. Recettes courtes, gestes précis, hygiène millimétrée. Sur l’ardoise, Matthieu note la température, les temps, les ingrédients. Moins de poudre et de promesses ; plus de lait, plus de maîtrise.

      ### 🚶‍♂️ Parcours avant l’ouverture
      Rien n’a été improvisé : formations en micro-transformation, visites d’ateliers, calcul des déperditions et des cadences, chaîne du froid. Un planning serré pour produire juste à temps, sans stock inutile. Et un ton clair : parler simplement de ce qui est compliqué, avec l’humilité du fabricant.

      ### 🥛 La vie du lieu
      On passe « voir si c’est sorti », on revient chercher « ceux d’hier, ils étaient incroyables ». Les enfants collent leur nez à la vitre, posent mille questions. Les écoles visitent ; on goûte, on sent, on apprend. Les habitants suivent les saisons et les essais. Peu à peu, la laiterie devient une évidence : le frais a un visage, une adresse, un prénom.

      ### 💡 Pourquoi c’est inspirant
      - Transparence tenue dans la durée
      - Produits ultra-frais qui racontent une filière locale
      - Pédagogie douce qui redonne du sens à l’alimentation

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
      Madame Bergamote, c’est une parenthèse lumineuse à deux pas de Stanislas. On y entre pour un thé fumant ou une tarte de saison, on y reste pour l’accueil et l’odeur de beurre qui sort du four. Carte courte qui tient ses promesses, régularité, goût de reviens-y.

      ### 🚶‍♀️ Parcours avant l’ouverture
      Derrière le comptoir, une passionnée passée par la formation et la restauration/vente. Carnet de grammages, températures, temps de repos ; recettes ajustées pour tenir le samedi de rush comme le mardi pluvieux. Petite logistique d’un salon de thé : flux, vitrine de 11 h, commandes à la journée, réponse au prénom.

      ### 🍰 La vie du lieu
      Goûters partagés, lecture au calme, ateliers de pâtisserie ou d’aquarelle. La vitrine suit les saisons ; assiettes généreuses, prix raisonnables, ambiance douce. Rien de spectaculaire : c’est tenu. Et c’est ce qui fidélise.

      ### 💡 Pourquoi c’est inspirant
      - Patience et précision au service d’un lieu régulier
      - Fait-maison simple et tenu
      - Commerce d’accueil qui tisse une communauté

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
      GALAPAGA porte bien son nom : doux, coloré, posé. Laure y réunit des marques responsables (puériculture, jeux, mode), choisies pour leurs matériaux, leur durabilité et leur bon sens. La boutique n’est pas un défilé d’objets : c’est un parcours. On touche, on comprend, on achète mieux. Des ateliers parents-enfants ponctuent l’année.

      ### 👣 Parcours avant l’ouverture
      Ancienne éducatrice de jeunes enfants, Laure voulait un commerce pédagogique. Fiches claires (origine de la matière, durabilité), démonstrations, adhésion à la monnaie locale Florain pour ancrer l’économie dans le territoire. Elle apprend la vie d’une petite boutique : commandes sans sur-stock, récit des produits, accueil des questions.

      ### 🧩 La vie du lieu
      On peut venir « juste pour comprendre ». Essais de portage, petite réparation, troc de vêtements encore bons. Ambiance bienveillante, prix explicites, retours écoutés. Peu à peu, la boutique devient un tiers-lieu léger.

      ### 💡 Pourquoi c’est inspirant
      - Pédagogie au cœur de l’expérience d’achat
      - Économie locale et circulaire au quotidien
      - Commerce qui donne envie d’agir simplement

      —
      📍 Adresse : 34 Boulevard de Baudricourt, 54600 Villers-lès-Nancy
      📰 Source : L’Est Républicain
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
      Choisir une franchise, pour Aude, c’est accélérer sans partir de zéro : process éprouvés, achats centralisés, formation initiale. Elle garde l’essentiel pour elle : accueil, régularité, ambiance. Son café doit être un repère simple et bien tenu.

      ### 🧰 Parcours avant l’ouverture
      Étude d’enseignes, échanges avec des franchisés, notes sur flux et stocks. Validation de l’emplacement, recrutement d’une équipe locale, apprentissage du rythme (vitrine 11 h, rush 16 h, fermeture douce). Quelques semaines d’ajustement, puis la mécanique se pose.

      ### ☕ La vie du lieu
      Matins petit-déj’ et cafés à emporter ; après-midi cookies et pauses réconfort. Touche personnelle : playlists douces, partenariats créateurs du coin, opérations solidaires. Rien d’extravagant, mais une constance qui fait revenir.

      ### 💡 Pourquoi c’est inspirant
      - Reconversion pragmatique et assumée
      - Process au service d’un accueil personnel
      - Régularité qui gagne la confiance du quartier

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
      Alex’s Pastries fabrique des entremets soignés et des gâteaux personnalisés qui racontent une personne, une table, une fête. Le modèle est simple : commande pour éviter le gâchis, ateliers pour transmettre. Recettes équilibrées, décors précis, échanges clients intégrés à la création.

      ### 🎓 Parcours avant l’ouverture
      Ancienne enseignante, Alex prépare un CAP pâtisserie, enchaîne les stages, documente ses essais. Calendrier de production, prise de rendez-vous en ligne, kit de devis clair. Le bouche-à-oreille fait le reste : peu, mais très bien.

      ### 🎂 La vie du lieu
      Week-ends d’événements (anniversaires, mariages) ; semaine en ateliers à domicile ou en tiers-lieu. On apprend la mousse qui tient, la ganache qui brille, la poche qui rassure. Les retours nourrissent les recettes. Un artisanat joyeux, précis et humain.

      ### 💡 Pourquoi c’est inspirant
      - Modèle agile et frugal pour se lancer
      - Progression par petites itérations et retours
      - Exigence artisanale au service de vraies personnes

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
      À Toul, Saveurs Exotics met des couleurs et des arômes dans le quotidien. Derrière le comptoir, une passionnée de cuisine et de partage, passée du conseil en ressources humaines à l’entrepreneuriat gourmand. Objectif : faire découvrir des saveurs d’enfance, valoriser des producteurs méconnus, créer un lieu où l’on vient autant pour échanger que pour acheter.

      Étals choisis avec soin : épices des Antilles, condiments africains, boissons artisanales, confitures maison. Chaque référence est sélectionnée pour sa qualité, son histoire et son authenticité. Et parce que la curiosité ouvre l’appétit, le magasin propose un bar à salade et des dégustations thématiques.

      ### 🚶‍♀️ Parcours avant l’ouverture
      Après des années dans la formation, besoin de retrouver du concret. Salons, échanges avec des importateurs, recettes maison affinées. Étudier les produits, apprendre la gestion d’un stock vivant, comprendre les attentes du public : un nouvel apprentissage mené avec rigueur et enthousiasme.

      ### 🍛 La vie du lieu
      Chaque semaine s’anime avec ateliers cuisine, soirées dégustation, playlists créoles et recettes partagées. Les habitués viennent pour un conseil, une idée, un mot. Ici, on parle autant de goût que de souvenirs. En deux ans, l’adresse devient un point de rencontre entre cultures et générations.

      ### 💡 Pourquoi c’est inspirant
      - Reconversion authentique qui fait du commerce un vecteur de lien
      - Pédagogie comme ingrédient de la réussite
      - Commerce local qui redonne des couleurs au centre-ville

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
      L’Écrin est un petit lieu convivial au cœur de Damelevières, où l’on se sent accueilli dès le seuil franchi. Après des années en EHPAD, la repreneuse voulait un endroit pour rassembler sans prétention. Un bar-lounge où la carte reste courte, les visages familiers et la musique bien choisie.

      Entre un verre de vin, un café ou une planche apéro, les gens se retrouvent. Chaque semaine, une soirée thématique : karaoké, blind test, concert acoustique, jeux. Rien d’excessif, mais tenu, sincère et régulier. La simplicité fait l’ambiance.

      ### 🚶‍♀️ Parcours avant l’ouverture
      Dossier de licence, formation en gestion, recherche de financement. Entourage mobilisé, apprentissage sur le tas de la compta, de la com’ et des autorisations. Chaque étape devient une petite victoire.

      ### 🎵 La vie du lieu
      Plus qu’un bar : un rendez-vous de quartier. Jeunes qui chantent, seniors qui discutent l’après-midi, associations locales qui s’y ancrent. Un commerce de proximité où l’on peut simplement être bien.

      ### 💡 Pourquoi c’est inspirant
      - Reprise audacieuse qui montre qu’on peut changer de vie à tout âge
      - Programmation légère mais constante, au service du lien social
      - Le “prendre soin” transposé à l’accueil et à la convivialité

      —
      📍 Adresse : 19 Rue de la Libération, 54360 Damelevières
      📸 Crédit photo : L’Écrin
      📰 Source : L’Est Républicain (2025)
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
      Après vingt ans en entrepôt, Frédéric choisit de devenir artisan taxi. Au-delà du volant, c’est une nouvelle manière d’être utile. Il transporte des patients, des enfants, des habitants isolés, avec la même attention. Ponctuel, poli, fiable, il devient pour beaucoup un repère discret.

      ### 🔧 Parcours avant l’ouverture
      Formation, carte professionnelle, choix du véhicule, micro-entreprise, conventions avec les caisses de santé. Beaucoup d’apprentissage, souvent seul, avec l’aide d’anciens du métier. En échange, une vraie autonomie, des horaires adaptés, une relation de confiance.

      ### 🤝 La vie du service
      Dans les villages autour de Nancy, son numéro circule de bouche à oreille. Rendez-vous médicaux, gares, retours tardifs : toujours une voix calme, un trajet sûr, un mot gentil. Sa spécialité, au fond : rendre la mobilité plus humaine.

      ### 💡 Pourquoi c’est inspirant
      - Reconversion sobre et utile qui recrée du lien de proximité
      - Service artisanal au cœur du quotidien
      - La fiabilité comme vocation

      —
      📍 Secteur : Saulxures-lès-Nancy & environs
      📸 Crédit photo : Fred’Taxi
      📰 Source : Témoignages locaux
    MD
    quote: "Ce que je vends ? La fiabilité."
  }
]

# ——— Ajouts “Belles histoires” depuis Destination Nancy (pp.16–17)
stories += [
  {
    slug: "cerfav-vannes-le-chatel",
    title: "CERFAV — Arts verriers (Vannes-le-Châtel)",
    category: "formation",
    chapo: "Un lieu unique où l’on souffle le verre, on apprend, on crée — du premier cœur en duo à la boule de Noël, la magie devient geste.",
    description: "Formations et ateliers grand public (soufflage, fusing), galerie-boutique et expositions autour du verre.",
    location: "Rue du Grippot, 54112 Vannes-le-Châtel",
    latitude: 48.5555, longitude: 5.8476,
    source_name: "Destination Nancy",
    source_url: "/stories/articles/destination-nancy.pdf",
    image_url: "stories/cerfav.jpg",
    body: <<~MD,
      ### 🌿 Le projet
      À Vannes-le-Châtel, le CERFAV mélange transmission, création et émerveillement. On vient pour voir le verre prendre forme au bout de la canne, essayer un premier geste et repartir avec une pièce qui a une histoire. Les ateliers grand public (soufflage d’ornements, fusing en couleurs) et les expositions rendent le geste verrier accessible, sans rien enlever à sa poésie.

      ### 🚶‍♀️ Parcours et pédagogie
      C’est d’abord un centre de formation et de recherche reconnu — mais la pédagogie ne s’arrête pas aux pros. Formats courts dès 6 ans, pensés pour réussir en sécurité, avec un résultat concret (boules de Noël, cœurs soufflés, pièces en verre fusionné). Apprendre par le faire, comprendre la chaleur, la gravité, le refroidissement.

      ### 🔥 La vie du lieu
      L’année est rythmée par des temps forts : ateliers de Noël, sessions Saint-Valentin, découverte du fusing pendant l’hiver. La galerie-boutique prolonge l’expérience et l’Office de Tourisme métropolitain diffuse des créations en ville. Réservation en ligne, accueil bienveillant, équipe passionnée.

      ### 💡 Pourquoi c’est inspirant
      - Savoir-faire d’exception rendu accessible
      - Ateliers courts qui réenchantent l’apprentissage
      - Lien direct entre créateurs, habitants et visiteurs

      —
      📍 Rue du Grippot, 54112 Vannes-le-Châtel
      📸 Crédit photo : CERFAV
      📰 Source : Destination Nancy, p.16
    MD
    quote: "Le verre se travaille comme une histoire : souffle, patience… et lumière."
  },


  {
    slug: "pierre-percee-plein-air-relance-er",
    title: "Pierre-Percée (54) — Parier sur le plein air pour relancer un village",
    category: "entreprendre",
    chapo: "Au cœur du Pays du Cristal, Pierre-Percée mise sur la nature et les émotions à ciel ouvert pour faire revenir les visiteurs et redonner souffle à tout un territoire.",
    description: "Hébergements légers, activités nautiques, sentiers et nouvelles expériences de plein air pour relancer un village et son économie locale.",
    location: "Lac de Pierre-Percée, 54540 Pierre-Percée",
    latitude: 48.498, longitude: 6.912,
    source_name: "L’Est Républicain",
    source_url: "https://www.estrepublicain.fr/economie/2025/01/24/pierre-percee-veut-monter-en-gamme-pour-seduir-les-visiteurs",
    image_url: "https://images.unsplash.com/photo-1526483360412-f4dbaf036963?q=80&w=1600&auto=format&fit=crop",
    body: <<~MD,
      ### 🌿 Le projet
      Dans les Vosges du Nord, le lac de Pierre-Percée a toujours eu un charme particulier : forêts profondes, reflets verts, silence. Mais les visiteurs se faisaient plus rares, les hébergements vieillissaient, les activités tournaient en rond. La commune et ses partenaires ont donc repensé le site comme un écosystème vivant, ouvert aux initiatives locales et à la nature sous toutes ses formes. Le pari : faire du plein air un moteur de relance durable.

      Autour du lac, les nouveaux aménagements misent sur la sobriété et le sens du lieu : hébergements légers en bois, espaces de bivouac, sentiers mieux balisés, zones de baignade surveillées et accueil repensé pour cyclistes et randonneurs. L’objectif est d’attirer sans dénaturer.

      ### 🚶‍♀️ Parcours et méthode
      Le projet réunit mairie, acteurs touristiques, associations sportives, hébergeurs et habitants. Chacun apporte sa contribution : logistique, communication, circuits courts, produits du terroir. Ensemble, ils ont posé un plan à cinq ans avec une idée centrale : remettre les habitants au cœur de la dynamique. Les jeunes participent via des chantiers, les artisans locaux interviennent sur les travaux, les associations sportives encadrent les activités nautiques.

      ### 🚣‍♂️ La vie du lieu
      Les week-ends d’été, le lac retrouve son énergie. Paddle, escalade, randonnée, tyrolienne, marchés locaux, concerts au bord de l’eau : tout est pensé pour faire vivre la montagne autrement. L’hiver, le calme revient mais le travail continue : entretiens, bilans, préparation de la prochaine saison. Les commerçants sentent déjà la différence : plus de passage, plus de vitalité, et des visiteurs qui reviennent. Le lac n’est plus une parenthèse mais une destination.

      ### 💡 Pourquoi c’est inspirant
      - Relance territoriale fondée sur la coopération 🏞️
      - Emplois saisonniers et durables créés localement
      - Transition touristique vers le sobre et le sensible 🌲

      —
      📍 Adresse : Lac de Pierre-Percée, 54540 Pierre-Percée
      📸 Crédit photo : Office du Tourisme du Pays du Cristal
      📰 Source : L’Est Républicain (24 janvier 2025)
    MD
    quote: "La nature n’est pas un décor : c’est un avenir à habiter ensemble."
  },

  {
    slug: "le-lupin-atelier-ceramique-nancy",
    title: "Le Lupin — Atelier de céramique (Nancy)",
    category: "formation",
    chapo: "Un atelier familial, des cours et des stages pour apprivoiser la terre — et une box 100 % céramique, pensée à Nancy.",
    description: "Cours, initiations, pratique autonome encadrée, ventes éphémères et abonnement « La Box du Lupin ».",
    location: "5 Place de la Croix de Bourgogne, 54000 Nancy",
    latitude: 48.6867, longitude: 6.1842,
    source_name: "Destination Nancy",
    source_url: "/stories/articles/destination-nancy.pdf",
    image_url: "stories/le-lupin.jpg",
    body: <<~MD,
      ### 🌿 Le projet
      Le Lupin est un atelier de céramique tenu par deux artisans passionnés. C’est un lieu vivant : on façonne, on tourne, on émaille, on parle de gestes et de temps long. L’équipe propose des cours et initiations, mais aussi des temps de pratique autonome pour continuer à créer à son rythme. Des ventes éphémères ponctuent l’année.

      ### 🎁 Une box qui soutient l’artisanat
      Leur Box du Lupin (tous les deux mois) réunit des pièces faites main à Nancy — des objets utiles, sobres, touchants, livrés à domicile. Une porte d’entrée pour offrir local et apprendre à reconnaître la qualité d’une cuisson, d’un émail, d’un bord bien tourné.

      ### 🏺 La vie du lieu
      Atelier ouvert du lundi au samedi : cours, stages, créneaux d’atelier libre. Pédagogie rassurante pour les débutants, exigence des finitions pour les avancés. On se croise, on s’encourage, on compare des terres, on passe lors d’une vente d’artisans. Une vraie communauté de mains dans la terre.

      ### 💡 Pourquoi c’est inspirant
      - École du geste chaleureuse, pour tous niveaux
      - Modèle mêlant formation et diffusion locale
      - Temps long de l’artisanat rendu désirable au quotidien

      —
      📍 5 place de la Croix de Bourgogne, Nancy
      📸 Crédit photo : Le Lupin
      📰 Source : Destination Nancy, p.17
    MD
    quote: "Apprendre la terre, c’est apprendre la patience… et la joie du concret."
  },

  {
    slug: "club-sandwich-illustration-nancy",
    title: "Club Sandwich — Atelier-boutique d’illustrations (Nancy)",
    category: "rencontres",
    chapo: "Deux illustratrices, une vitrine colorée et des rendez-vous réguliers pour faire vibrer l’imaginaire — du dessin à la sérigraphie.",
    description: "Boutique-atelier, sérigraphies, objets illustrés, événements et rencontres avec des artistes locaux.",
    location: "21 Rue de la Source, 54000 Nancy",
    latitude: 48.6889, longitude: 6.1785,
    source_name: "Destination Nancy",
    source_url: "/stories/articles/destination-nancy.pdf",
    image_url: "stories/club-sandwich.jpg",
    body: <<~MD,
      ### 🌿 Le projet
      Club Sandwich (ex-Cueillir) est la boutique-atelier de deux illustratrices, Chloé Revel et Cami Berni. Leur univers mêle Art nouveau, faune et flore, Japon et estampe — décliné en illustrations et sérigraphies qui accrochent l’œil et le sourire. On entre pour une affiche, on reste pour la conversation sur un papier, une encre, une trame, un cadrage.

      ### ✍️ Parcours et engagement
      Très investies dans le tissu associatif et culturel, elles conçoivent la boutique comme un lieu de circulation : accueillir d’autres illustrateurs, organiser des temps forts, provoquer des rencontres. On peut aussi commander une illustration personnalisée — une manière joyeuse de célébrer une histoire, un lieu, une passion.

      ### 🎨 La vie du lieu
      Ouverte du mercredi au samedi (14 h – 18 h), la boutique devient un point de ralliement pour curieux, étudiants et amoureux d’objets imprimés. Entre petites séries, pochettes, pins et pièces chinées, on trouve de quoi offrir local sans se ruiner. Les vitrines changent au fil des saisons : revenir est toujours une bonne idée.

      ### 💡 Pourquoi c’est inspirant
      - Atelier-boutique qui crée de la rencontre
      - Illustration vivante, entre artisanat et culture populaire
      - Commandes sur mesure qui racontent les gens

      —
      📍 21 rue de la Source, 54000 Nancy
      📸 Crédit photo : Club Sandwich
      📰 Source : Destination Nancy, p.17
    MD
    quote: "Donner à voir, et donner envie de créer."
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
