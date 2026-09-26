# 20 opportunités : 4 par catégorie ; 10 datées dans les 6 prochaines semaines, 6 permanentes,
# 4 passées. 8 fiches ont 2 à 4 photos, 10 en ont une, 2 n'en ont aucune (test du repli).
# Dates calculées à partir de Date.current.

MJC = { location: "MJC Lillebonne, 14 rue du Cheval Blanc, 54000 Nancy", address: "14 rue du Cheval Blanc",
        city: "Nancy", postal_code: "54000", latitude: 48.6949, longitude: 6.1889 }.freeze
STANISLAS = { city: "Nancy", postal_code: "54000" }.freeze
ORBOR = { location: "Espace Innovation, 5 rue Jacques Villermaux, 54000 Nancy", address: "5 rue Jacques Villermaux",
          city: "Nancy", postal_code: "54000", latitude: 48.6893, longitude: 6.1855 }.freeze

def jour(decalage) = Date.current + decalage

def opportunite(photos:, **attrs)
  fiche = Opportunity.create!({ is_active: true, source: "seed" }.merge(attrs))
  SeedsDemo.joindre_photos(fiche, photos)
  fiche
end

# ─── 10 datées (à venir, dans les 6 semaines) ──────────────────────────────────────────────
opportunite(
  category: "ecologiser", title: "Plantons ensemble des arbres au parc de la Pépinière",
  organization: "Collectif Canopée Nancy", published_at: jour(-9),
  starts_on: jour(6), ends_on: jour(6), start_time: "09:00", end_time: "12:00",
  location: "Parc de la Pépinière, rue Sainte-Catherine, 54000 Nancy", address: "Rue Sainte-Catherine",
  city: "Nancy", postal_code: "54000", latitude: 48.6976, longitude: 6.1795,
  is_free: true, tags: "Arbres, Plein air, En famille",
  description: "Un matin pour redonner de l'ombre à la ville : le Collectif Canopée plante une trentaine de jeunes arbres " \
               "dans le parc, avec les habitantes et habitants du quartier.\n\nOutils, gants et petit-déjeuner sont fournis. " \
               "Venez avec des chaussures qui ne craignent pas la terre.",
  audience: "Toutes les personnes qui aiment la nature, avec ou sans expérience du jardinage. Les enfants sont les bienvenus, accompagnés.",
  programme: [ "Accueil et petit-déjeuner", "Démonstration de plantation par un jardinier de la Ville", "Plantation par petits groupes", "Pose des tuteurs et arrosage", "Pot de clôture" ],
  quote: "Un arbre planté aujourd'hui, c'est de l'ombre pour dans dix ans.", quote_author: "Une bénévole du collectif",
  cta_button_text: "Je m'inscris à la plantation", cta_button_url: "https://example.com/canopee/plantation",
  contact_email: "canopee@example.com",
  photos: %w[arbres1 arbres2 vegetalisation jardin1]
)

opportunite(
  category: "benevolat", title: "Distribution alimentaire : renforts de bénévoles",
  organization: "Épicerie solidaire Le Panier Lorrain", published_at: jour(-14),
  starts_on: jour(2), ends_on: jour(2), start_time: "14:00", end_time: "17:30",
  location: "Épicerie solidaire Le Panier Lorrain, 12 rue Saint-Dizier, 54000 Nancy", address: "12 rue Saint-Dizier",
  city: "Nancy", postal_code: "54000", latitude: 48.6912, longitude: 6.1868,
  is_free: true, tags: "Solidarité, Alimentation",
  description: "Chaque semaine, l'épicerie solidaire accueille plus de cent familles. Pour tenir la distribution du " \
               "mercredi, l'équipe cherche des bénévoles pour trier, ranger et accompagner les personnes dans les rayons.\n\n" \
               "- Aucune compétence particulière requise\n- Une demi-journée suffit\n- Une formation courte est donnée sur place",
  audience: "Toute personne majeure disponible un mercredi après-midi, à l'aise pour accueillir avec bienveillance.",
  programme: [ "Accueil et présentation de l'équipe", "Mise en rayon des produits du jour", "Accompagnement des familles pendant la distribution", "Rangement et débriefing" ],
  quote: "Ici, on ne donne pas, on partage : chacun repart avec plus qu'un panier.", quote_author: "Une bénévole de l'épicerie",
  cta_button_text: "Je deviens bénévole", cta_button_url: "https://example.com/panier-lorrain/benevoles",
  photos: %w[restos]
)

opportunite(
  category: "formation", title: "Atelier découverte de la céramique",
  organization: "Atelier Terre & Feu", published_at: jour(-5),
  starts_on: jour(9), ends_on: jour(9), start_time: "14:00", end_time: "17:00",
  is_free: false, tags: "Céramique, Créativité, Manuel",
  description: "Modelage, engobes et petites glaçures : trois heures pour réaliser votre première pièce, guidé par une céramiste.\n\n" \
               "Votre création sera cuite à l'atelier et disponible deux semaines plus tard.",
  audience: "Adultes et adolescents dès 14 ans, débutantes et débutants. Matériel fourni, 12 places.",
  programme: [ "Présentation des techniques de modelage", "Réalisation d'une pièce (bol, assiette ou petit objet)", "Décor aux engobes", "Choix des glaçures pour la cuisson" ],
  quote: "On arrive avec deux mains, on repart avec un objet qui nous ressemble.", quote_author: "La céramiste de l'atelier",
  cta_button_text: "Réserver ma place", cta_button_url: "https://example.com/terre-et-feu/atelier",
  photos: %w[atelier1 atelier2],
  **MJC
)

opportunite(
  category: "rencontres", title: "Soirée salsa, bachata et kizomba",
  organization: "Association Les Nuits Latines", published_at: jour(-3),
  starts_on: jour(13), ends_on: jour(13), start_time: "20:00", end_time: "23:30",
  is_free: false, tags: "Danse, Soirée, Musique",
  description: "Initiation d'une demi-heure pour chaque danse, puis bal ouvert jusqu'à la fin de soirée. On vient seul·e ou à plusieurs : " \
               "les partenaires tournent, l'ambiance est faite pour se rencontrer.",
  audience: "Tout niveau, de la première danse aux habitués. Pas besoin de venir en couple.",
  programme: [ "20h : initiation salsa", "20h45 : initiation bachata", "21h30 : initiation kizomba", "22h : bal ouvert" ],
  quote: "On ne vient pas pour bien danser, on vient pour danser ensemble.", quote_author: "Un animateur des Nuits Latines",
  cta_button_text: "Réserver sa soirée", cta_button_url: "https://example.com/nuits-latines/soiree",
  photos: %w[salsa bachata kizomba],
  **MJC
)

opportunite(
  category: "entreprendre", title: "Café des créateurs : de l'idée au projet",
  organization: "Réseau Entreprendre Lorraine (exemple)", published_at: jour(-2),
  starts_on: jour(4), ends_on: jour(4), start_time: "18:30", end_time: "20:30",
  location: "Café de la place Stanislas, 54000 Nancy", address: "Place Stanislas", latitude: 48.6937, longitude: 6.1832, **STANISLAS,
  is_free: true, tags: "Création d'activité, Réseau",
  description: "Une idée d'activité en tête ? Chaque mois, des créatrices et créateurs racontent leurs débuts, leurs erreurs et leurs " \
               "premières victoires, puis répondent à vos questions autour d'un verre.",
  audience: "Toute personne qui pense à créer une activité, un commerce ou une association, quel que soit l'avancement du projet.",
  programme: [ "Accueil autour d'un café", "Trois témoignages de trois minutes", "Questions-réponses", "Rencontres informelles" ],
  cta_button_text: "Je réserve ma place", cta_button_url: "https://example.com/cafe-des-createurs",
  photos: %w[serre]
)

opportunite(
  category: "rencontres", title: "Visite guidée : la place Stanislas et son histoire",
  organization: "Nancy à pied (exemple)", published_at: jour(-20),
  starts_on: jour(16), ends_on: jour(16), start_time: "15:00", end_time: "16:30",
  location: "Place Stanislas, 54000 Nancy", address: "Place Stanislas", latitude: 48.6936, longitude: 6.1833, **STANISLAS,
  is_free: true, tags: "Patrimoine, Balade, En famille",
  description: "Grilles dorées, fontaines et statue du duc Stanislas : une guide raconte comment un souverain a transformé une ville en scène " \
               "et pourquoi la place est classée à l'UNESCO.\n\nLa visite se termine devant l'Arc Héré.",
  audience: "Habitantes et habitants curieux de leur ville, visiteurs, familles. Visite accessible aux personnes à mobilité réduite.",
  programme: [ "Rendez-vous devant la statue", "L'hôtel de ville et les grilles de Jean Lamour", "Les fontaines de Guibal", "L'Arc Héré et la Carrière" ],
  quote: "Nancy est une ville qu'on redécouvre à chaque fois qu'on lève les yeux.", quote_author: "La guide",
  cta_button_text: "Je m'inscris à la visite", cta_button_url: "https://example.com/nancy-a-pied/stanislas",
  photos: %w[stanislas1 stanislas2 stanislas3]
)

opportunite(
  category: "ecologiser", title: "Balade végétale le long du canal",
  organization: "Les Herbes Folles", published_at: jour(-6),
  starts_on: jour(20), ends_on: jour(20), start_time: "10:00", end_time: "12:30",
  location: "Quai Claude-le-Lorrain, 54000 Nancy", address: "Quai Claude-le-Lorrain",
  city: "Nancy", postal_code: "54000", latitude: 48.6925, longitude: 6.1950,
  is_free: true, tags: "Biodiversité, Balade, Nature en ville",
  description: "Le canal est un couloir de nature en pleine ville. Une botaniste vous apprend à reconnaître les plantes des berges et des murs, " \
               "et à distinguer celles qu'on peut laisser pousser.",
  audience: "Toute personne curieuse de la nature ordinaire, dès 8 ans. Prévoir de bonnes chaussures.",
  programme: [ "Départ du quai", "Reconnaître les plantes des murs et des pieds d'arbres", "Le rôle du lierre et des friches", "Petit herbier collectif" ],
  quote: "Il suffit de regarder par terre pour voir que la ville est vivante.", quote_author: "La botaniste des Herbes Folles",
  cta_button_text: "Je m'inscris à la balade", cta_button_url: "https://example.com/herbes-folles/balade",
  photos: %w[canal1 canal2 canal3]
)

opportunite(
  category: "formation", title: "Cours de cuisine du monde",
  organization: "Cuisines en partage", published_at: jour(-1),
  starts_on: jour(25), ends_on: jour(25), start_time: "18:00", end_time: "21:00",
  location: "Atelier de cuisine, 8 rue des Ponts, 54000 Nancy", address: "8 rue des Ponts",
  city: "Nancy", postal_code: "54000", latitude: 48.6935, longitude: 6.1834,
  is_free: false, tags: "Cuisine, Voyage, Convivialité",
  description: "Chaque mois, une cuisinière ou un cuisinier d'ici ou d'ailleurs vous apprend trois plats de son pays. On cuisine, puis on dîne ensemble.",
  audience: "Adultes, tous niveaux. Le repas est compris, les places sont limitées à 10.",
  programme: [ "Découverte des produits et des épices", "Préparation des trois plats", "Dressage", "Repas partagé" ],
  cta_button_text: "Je réserve un couvert", cta_button_url: "https://example.com/cuisines-en-partage/cours",
  photos: %w[art-culinaire]
)

opportunite(
  category: "entreprendre", title: "Portes ouvertes de la fromagerie du Vieux-Nancy",
  organization: "Fromagerie de la Grande Rue (exemple)", published_at: jour(-8),
  starts_on: jour(31), ends_on: jour(32), start_time: "10:00", end_time: "18:00",
  location: "Fromagerie de la Grande Rue, 21 Grande Rue, 54000 Nancy", address: "21 Grande Rue",
  city: "Nancy", postal_code: "54000", latitude: 48.6950, longitude: 6.1823,
  is_free: true, tags: "Artisanat, Fromage, Terroir",
  description: "Une fromagère affineuse ouvre sa cave : découverte de l'affinage, dégustations de fromages lorrains et échanges sur le métier " \
               "pour celles et ceux qui pensent à se reconvertir dans l'artisanat.",
  audience: "Curieux et gourmands, et toute personne qui envisage un changement de métier vers l'artisanat alimentaire.",
  programme: [ "Visite de la cave d'affinage", "Dégustation commentée", "Rencontre : se reconvertir dans l'artisanat", "Vente à prix coûtant en fin de journée" ],
  cta_button_text: "Je viens aux portes ouvertes", cta_button_url: "https://example.com/fromagerie-grande-rue/portes-ouvertes",
  photos: %w[fromagerie]
)

opportunite(
  category: "rencontres", title: "Stage de sculpture sur pierre",
  organization: "Atelier de la Carrière", published_at: jour(-12),
  starts_on: jour(38), ends_on: jour(39), start_time: "09:30", end_time: "17:00",
  location: "Atelier de la Carrière, 12 rue des Michottes, 54000 Nancy", address: "12 rue des Michottes",
  city: "Nancy", postal_code: "54000", latitude: 48.6890, longitude: 6.1770,
  is_free: false, tags: "Sculpture, Stage, Art",
  description: "Deux jours pour tailler votre première pierre, avec les conseils d'un sculpteur. Ciseaux, maillets et lunettes de protection sont prêtés.",
  audience: "Adultes débutants ou confirmés, sans prérequis. Tenue de travail conseillée.",
  programme: [ "Choix de la pierre et du dessin", "Dégrossissage", "Taille et finitions", "Exposition des pièces en fin de stage" ],
  cta_button_text: "Je m'inscris au stage", cta_button_url: "https://example.com/atelier-carriere/stage",
  photos: %w[workshop-artistique]
)

# ─── 6 permanentes (schedule_text, sans dates) ─────────────────────────────────────────────
opportunite(
  category: "ecologiser", title: "Rejoignez le jardin partagé de Boudonville",
  organization: "Association Les Mains Vertes", published_at: jour(-60),
  schedule_text: "Ouvert toute l'année, permanences le samedi de 9 h à 12 h",
  location: "Jardin partagé de Boudonville, rue de Boudonville, 54000 Nancy", address: "Rue de Boudonville",
  city: "Nancy", postal_code: "54000", latitude: 48.6800, longitude: 6.1650,
  is_free: true, tags: "Jardinage, Voisinage, Potager",
  description: "Une trentaine de parcelles cultivées en commun, un composteur, une cabane à outils : le jardin accueille chaque samedi de nouvelles " \
               "voisines et voisins qui veulent mettre les mains dans la terre.",
  audience: "Habitantes et habitants du quartier, débutants comme jardiniers confirmés. Une petite cotisation annuelle finance les outils.",
  programme: [ "Venir un samedi matin à la permanence", "Visite du jardin et rencontre des jardiniers", "Choix d'une parcelle ou d'un coin collectif", "Première plantation avec un parrain de jardin" ],
  quote: "Ici on cultive des tomates, mais surtout des amitiés.", quote_author: "Une jardinière des Mains Vertes",
  cta_button_text: "Je rejoins le jardin", cta_button_url: "https://example.com/mains-vertes/rejoindre",
  photos: %w[jardin2 jardin1 vegetalisation]
)

opportunite(
  category: "ecologiser", title: "Transformez une cour d'immeuble en petit jardin",
  organization: "Nancy Cours Vertes (exemple)", published_at: jour(-45),
  schedule_text: "Permanence conseil sur rendez-vous, toute l'année",
  location: "Permanence, 8 rue de la Source, 54000 Nancy", address: "8 rue de la Source",
  city: "Nancy", postal_code: "54000", latitude: 48.6870, longitude: 6.1750,
  is_free: true, tags: "Végétalisation, Copropriété, Biodiversité",
  description: "Une cour bétonnée, un mur nu, une entrée d'immeuble sans vie : des conseillers vous aident à imaginer un projet de végétalisation " \
               "et à convaincre votre copropriété.",
  audience: "Locataires et copropriétaires qui souhaitent verdir leur cour, leur pied de mur ou leur entrée d'immeuble.",
  programme: [ "Visite de votre cour et diagnostic gratuit", "Choix des plantes adaptées à l'ombre ou au soleil", "Aide à la demande d'autorisation", "Chantier participatif avec les voisins" ],
  quote: "Un simple pied de mur planté change le regard de tout un immeuble.", quote_author: "Une conseillère de Nancy Cours Vertes",
  cta_button_text: "Prendre rendez-vous", cta_button_url: "https://example.com/cours-vertes/rendez-vous",
  photos: %w[cour1 cour2]
)

opportunite(
  category: "benevolat", title: "Donnez vos vieux téléphones, ils auront une seconde vie",
  organization: "Recycl'Phone Lorraine (exemple)", published_at: jour(-30),
  schedule_text: "Point de collecte ouvert du mardi au samedi",
  location: "Point de collecte, place Charles III, 54000 Nancy", address: "Place Charles III",
  city: "Nancy", postal_code: "54000", latitude: 48.6942, longitude: 6.1795,
  is_free: true, tags: "Recyclage, Numérique, Réemploi",
  description: "Les téléphones et chargeurs oubliés dans un tiroir sont testés, reconditionnés ou recyclés par une équipe de bénévoles et de " \
               "salariés en insertion. Déposez-les, ou rejoignez l'équipe de tri.",
  audience: "Tout le monde, pour déposer ; les personnes qui aiment le bricolage électronique pour donner un coup de main.",
  programme: [ "Déposer les appareils au point de collecte", "Tri et effacement sécurisé des données", "Reconditionnement ou recyclage" ],
  quote: "Un téléphone sur trois dort dans un tiroir : on lui rend une vie.", quote_author: "Un bénévole du tri",
  cta_button_text: "Je dépose ou je donne un coup de main", cta_button_url: "https://example.com/recycl-phone/deposer",
  photos: %w[recyclage-telephones]
)

opportunite(
  category: "formation", title: "Apprendre le français : ateliers de conversation",
  organization: "Collectif Langues et Liens", published_at: jour(-90),
  schedule_text: "Chaque mardi et jeudi de 18 h à 19 h 30, toute l'année, sans inscription",
  is_free: true, tags: "Français langue étrangère, Conversation, Solidarité",
  description: "Des ateliers pour parler, écouter et se faire comprendre, dans une ambiance bienveillante. On y vient pour apprendre le français " \
               "comme pour le pratiquer avec des bénévoles.",
  audience: "Adultes qui apprennent le français, tous niveaux. Pas besoin de justificatif.",
  programme: [ "Accueil et petit goûter", "Groupes de conversation par niveau", "Jeux de langue et lecture d'articles", "Sortie mensuelle en ville" ],
  cta_button_text: "Je viens à un atelier", cta_button_url: "https://example.com/langues-et-liens/ateliers",
  photos: [],
  **MJC
)

opportunite(
  category: "entreprendre", title: "Permanence : créer son activité, par où commencer ?",
  organization: "Boutique de gestion (exemple)", published_at: jour(-75),
  schedule_text: "Permanences gratuites le jeudi après-midi, sur rendez-vous",
  is_free: true, tags: "Création d'activité, Accompagnement, Financement",
  description: "Statut, financement, premiers clients : un conseiller fait le point avec vous en une heure et vous oriente vers les bons dispositifs.",
  audience: "Personnes qui ont une idée d'activité et veulent savoir par où commencer, y compris en reconversion.",
  programme: [ "Présentation de votre idée", "Panorama des statuts", "Pistes de financement", "Feuille de route personnalisée" ],
  cta_button_text: "Prendre rendez-vous", cta_button_url: "https://example.com/boutique-gestion/rendez-vous",
  photos: [],
  **ORBOR
)

opportunite(
  category: "rencontres", title: "Atelier bijouterie en accès libre",
  organization: "Atelier Lune d'Or", published_at: jour(-50),
  schedule_text: "Ouvert le mercredi et le samedi après-midi, sur inscription",
  location: "Atelier Lune d'Or, 3 rue de la République, 54520 Laxou", address: "3 rue de la République",
  city: "Laxou", postal_code: "54520", latitude: 48.6868, longitude: 6.1410,
  is_free: false, tags: "Bijoux, Artisanat, Créativité",
  description: "Un établi, des outils et les conseils d'une bijoutière : venez fabriquer une bague ou un pendentif pendant les créneaux d'accès libre.",
  audience: "Adultes et adolescents dès 15 ans, sans expérience nécessaire.",
  programme: [ "Choix du bijou et du métal", "Découpe et mise en forme", "Soudure et finitions" ],
  cta_button_text: "Réserver un créneau", cta_button_url: "https://example.com/lune-d-or/creneaux",
  photos: %w[atelier2]
)

# ─── 4 passées ────────────────────────────────────────────────────────────────────────────
opportunite(
  category: "entreprendre", title: "Pitch Night — Grand Nancy Innovation",
  organization: "Grand Nancy Innovation", published_at: jour(-30),
  starts_on: jour(-2), ends_on: jour(-2), start_time: "17:00", end_time: "19:00",
  is_free: true, tags: "Pitch, Réseau, Innovation",
  description: "Trois minutes pour convaincre : des porteuses et porteurs de projet présentent leur idée devant un public bienveillant.",
  audience: "Créateurs d'activité, curieux et entrepreneurs de la Métropole.",
  programme: [ "Accueil", "Pitchs de trois minutes", "Retours du public", "Rencontres autour d'un verre" ],
  cta_button_text: "Voir les prochaines soirées", cta_button_url: "https://example.com/grand-nancy-innovation/pitch-night",
  photos: %w[pitch-night],
  **ORBOR
)

opportunite(
  category: "benevolat", title: "Nuit de la solidarité : recensement des personnes sans abri",
  organization: "Ville de Nancy et associations (exemple)", published_at: jour(-50),
  starts_on: jour(-25), ends_on: jour(-25), start_time: "20:00", end_time: "23:59",
  location: "Hôtel de ville, place Stanislas, 54000 Nancy", address: "Place Stanislas", latitude: 48.6910, longitude: 6.1810, **STANISLAS,
  is_free: true, tags: "Solidarité, Nuit, Bénévolat",
  description: "Une nuit pour aller à la rencontre des personnes sans abri, mieux connaître leurs besoins et orienter l'aide. Les équipes sont formées en début de soirée.",
  audience: "Bénévoles majeur·es disponibles une soirée, sans compétence particulière.",
  programme: [ "Formation des équipes", "Départ en binômes", "Retour et échanges" ],
  quote: "Une heure de marche, et on ne voit plus la ville comme avant.", quote_author: "Un bénévole de la dernière édition",
  cta_button_text: "Voir les prochaines actions", cta_button_url: "https://example.com/nuit-solidarite",
  photos: %w[restos recyclage-telephones]
)

opportunite(
  category: "benevolat", title: "Grand nettoyage de printemps au parc de la Cure d'Air",
  organization: "Nancy Propre Ensemble (exemple)", published_at: jour(-70),
  starts_on: jour(-40), ends_on: jour(-40), start_time: "09:00", end_time: "12:00",
  location: "Parc de la Cure d'Air, 54600 Villers-lès-Nancy", address: "Parc de la Cure d'Air",
  city: "Villers-lès-Nancy", postal_code: "54600", latitude: 48.6655, longitude: 6.1497,
  is_free: true, tags: "Nettoyage, Nature, En famille",
  description: "Gants, sacs et bonne humeur : une matinée pour ramasser les déchets du parc et sensibiliser à leur tri.",
  audience: "Familles, groupes d'amis, associations locales.",
  programme: [ "Briefing et distribution du matériel", "Ramassage par zones", "Pesée et tri des déchets", "Goûter offert" ],
  cta_button_text: "Voir les prochaines matinées", cta_button_url: "https://example.com/nancy-propre-ensemble",
  photos: %w[canal2]
)

opportunite(
  category: "formation", title: "Initiation au dessin d'observation",
  organization: "Atelier Terre & Feu", published_at: jour(-35),
  starts_on: jour(-12), ends_on: jour(-12), start_time: "10:00", end_time: "12:00",
  is_free: false, tags: "Dessin, Art, Débutants",
  description: "Regarder vraiment, puis dessiner ce qu'on voit : une matinée pour poser ses premiers traits, sans jugement.",
  audience: "Adultes débutants. Matériel fourni.",
  programme: [ "Exercices d'échauffement", "Dessin d'un objet", "Lumière et ombre" ],
  cta_button_text: "Voir les prochains ateliers", cta_button_url: "https://example.com/terre-et-feu/dessin",
  photos: %w[atelier1],
  **MJC
)
