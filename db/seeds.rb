# db/seeds.rb

puts "🧹 Nettoyage de la base de données..."
# Détruire toutes les entrées pour repartir sur une base propre
defined?(Story) && Story.destroy_all
defined?(Opportunity) && Opportunity.destroy_all


# ==============================================================================
# 1. LES BELLES HISTOIRES (STORIES) : 5 FICHES DÉCLIC
# ==============================================================================
puts "📖 Création des Belles Histoires (Stories)..."

stories_data = [
  # --- Fiche 1 : Valéria (Danse, Kiev) ---
  {
    title: "🩰 Elle quitte Kiev pour Danser à Nancy : l'élan d'une nouvelle vie",
    chapo: "« Pouvoir danser à Nancy m’a sauvée » : l'histoire inspirante de Valéria, danseuse professionnelle.",
    location: "Conservatoire du Grand Nancy, 3 Rue Michel Ney, 54000 Nancy",
    latitude: 48.6942,
    longitude: 6.1834,
    happened_on: Date.new(2022, 4, 1),
    source_name: "Grand Nancy Magazine",
    image_url: "https://images.unsplash.com/photo-1547153723-f3621473919e?q=80&w=1600&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    body: <<-HTML
      **Lorsque la guerre éclate**, Valéria Orendovska est forcée de fuir Kiev. Arrivée à Nancy, la ville lui offre un refuge et la met en contact avec le Ballet de Lorraine.
      **Le déclic** : Pouvoir danser la sauve. Elle valide ses diplômes au Conservatoire/Creps Lorraine, apprend le français et ouvre bientôt son propre studio. Son histoire prouve que la passion est le plus puissant des moteurs.

      ---

      **✨ Et moi, comment je peux avoir le Déclic ?**
      Trouvez votre refuge créatif : Cherchez les structures d'enseignement et les collectifs artistiques locaux (Ballet de Lorraine, MJC, Conservatoire). Ils offrent souvent un cadre structurant et un réseau pour se reconstruire.
    HTML
  },

  # --- Fiche 2 : Famille Pazderskyy (Communauté) ---
  {
    title: "👨‍👩‍👧‍👦 De Kiev à Nancy : l'unité retrouvée grâce à la Communauté",
    chapo: "Apprendre le français, se faire des amis : comment la famille Pazderskyy a trouvé ses repères à Nancy.",
    location: "MJC Bazin, Rue du Bon Secours, 54000 Nancy (Point de ralliement)",
    latitude: 48.6930,
    longitude: 6.1840,
    happened_on: Date.new(2022, 3, 7),
    source_name: "Grand Nancy Magazine",
    image_url: "https://images.unsplash.com/photo-1517487881594-27877ef9ef2f?q=80&w=1600&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    body: <<-HTML
      Arrivés en mars 2022, la famille Pazderskyy a été accueillie par une famille nancéienne. Malgré les difficultés, les enfants ont vite trouvé leur place à l'école et aux scouts. Ils ont ainsi pu se reconstruire grâce au tissu associatif local.

      ---

      **✨ Et moi, comment je peux avoir le Déclic ?**
      Devenez une famille d'accueil ou un mentor : Contactez les associations d'aide aux réfugiés pour offrir votre temps, que ce soit pour une aide aux devoirs ou simplement pour partager un café. Votre aide pour briser l'isolement est précieuse.
    HTML
  },

  # --- Fiche 8 (Fromagère Affineuse - Reconversion) ---
  {
    title: "🧀 Elle plaque la finance à Paris pour devenir fromagère affineuse à Nancy",
    chapo: "Bénédicte a troqué ses fichiers Excel contre des tomes de fromage. Un retour aux sources et au terroir nancéien.",
    location: "21 Grande Rue, 54000 Nancy",
    latitude: 48.6936,
    longitude: 6.1832,
    happened_on: Date.new(2023, 6, 3),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?q=80&w=1600&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    body: <<-HTML
      Après une carrière dans la finance parisienne, Bénédicte a ressenti le besoin d'un métier concret et en lien avec ses racines lorraines. Elle a suivi une formation, appris les techniques d'affinage et a ouvert sa propre fromagerie artisanale au cœur du Vieux-Nancy. Son histoire est celle d'une reconversion réussie.

      ---

      **✨ Et moi, comment je peux avoir le Déclic ?**
      Lancez-vous dans l'artisanat : Renseignez-vous auprès de la Chambre des Métiers et de l'Artisanat. De nombreux dispositifs d'aide à la reconversion et à la création d'entreprise sont disponibles pour ceux qui souhaitent "faire de leurs mains".
    HTML
  },

  # --- Fiche 9 (Laiterie Urbaine - Entreprendre) ---
  {
    title: "🐄 Il ramène la campagne en ville avec sa laiterie urbaine",
    chapo: "Matthieu voulait produire de ses mains. Il a installé une véritable laiterie en plein centre-ville.",
    location: "6 rue Saint-Nicolas, 54000 Nancy",
    latitude: 48.6885,
    longitude: 6.1815,
    happened_on: Date.new(2024, 1, 15),
    source_name: "France Bleu Sud Lorraine",
    image_url: "https://images.unsplash.com/photo-1536750372352-19e917d84878?q=80&w=1600&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    body: <<-HTML
      Issu d'une famille d'agriculteurs, Matthieu a choisi d'amener la production au consommateur. Sa micro-laiterie transforme le lait local en produits frais, vendus en circuit court. Ce modèle est une réponse moderne aux enjeux de l'alimentation durable et de la transparence.

      ---

      **✨ Et moi, comment je peux avoir le Déclic ?**
      Misez sur le circuit court : Contactez la Chambre d'Agriculture pour explorer les modèles d'agriculture et de production en zone urbaine. Devenir producteur, c'est répondre à un besoin croissant de proximité.
    HTML
  },

  # --- Fiche 10 : Jardin Participatif Plateau-de-Haye (Écologie / Lien Social) ---
  {
    title: "🥕 Le Jardin Cultive le Lien : quand l'Agriculture Urbaine change le Quartier",
    chapo: "Au cœur du Plateau de Haye, un jardin nourricier redéfinit le lien social et l'autonomie alimentaire.",
    location: "Parc des Carrières, Plateau-de-Haye, 54000 Nancy",
    latitude: 48.7105,
    longitude: 6.1668,
    happened_on: Date.new(2024, 10, 1),
    source_name: "Réseau de Jardins Participatifs",
    image_url: "https://images.unsplash.com/photo-1507721999472-8ed4b16d1a10?q=80&w=1600&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    body: <<-HTML
      Le parc des Carrières abrite un jardin participatif de 1400 m² qui est devenu un lieu d’échanges autour de la solidarité et du bien-manger. Porté par le Réseau de Jardins Participatifs, ce lieu a fait naître des projets comme le Fournil Solidaire. Nancy mise sur l'agriculture urbaine pour créer du lien social.

      ---

      **✨ Et moi, comment je peux avoir le Déclic ?**
      Mettez la main à la terre : Rejoignez le Réseau de Jardins Participatifs pour apprendre l'agroécologie urbaine et cultiver votre propre parcelle. C'est l'occasion d'avoir un engagement très concret et de vous impliquer.
    HTML
  }
]

# Insertion des Stories
stories_data.each do |data|
  Story.create!(data)
end


# ==============================================================================
# 2. LES OPPORTUNITÉS (OPPORTUNITIES) : 5 NOUVELLES FICHES + 3 EXEMPLES ORIGINAUX
# ==============================================================================
puts "🤝 Création des Opportunités (Opportunities)..."

opportunities_data = [
  # --- Fiche 3 : Un Toit pour les Migrants (Bénévolat) ---
  {
    title: "🏠 Recherche Garants : Offrez un Logement Digne",
    category: "benevolat",
    organization: "Un Toit pour les Migrants",
    location: "17 Rue Drouin, 54000 Nancy",
    latitude: 48.6945,
    longitude: 6.1795,
    starts_at: nil,
    image_url: "https://images.unsplash.com/photo-1558277258-0027f610e2ac?q=80&w=800&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    description: <<-HTML
      **L'association recherche des propriétaires solidaires** pour permettre aux familles et jeunes sans papiers de trouver un logement sûr. L’association se positionne comme garante financière auprès des propriétaires, assurant toutes les garanties.
      **Ce que vous faites :** Vous défendez le principe de fraternité et protégez des familles de l'habitat indigne.

      ---

      **🚀 Et moi, comment je peux avoir le Déclic ?**
      Si vous êtes propriétaire : Contactez directement l'association pour proposer votre logement. Si vous n'êtes pas propriétaire : L'association repose sur la générosité des donateurs. Faites un don pour soutenir financièrement leur action.
    HTML
  },

  # --- Fiche 4 : Repair Café (Écologiser) ---
  {
    title: "🔧 Repair Café : Apprenez à réparer vos Objets du Quotidien",
    category: "ecologiser",
    organization: "MJC Lillebonne / Collectif Zéro Déchet",
    location: "MJC Lillebonne, 14 Rue du Cheval Blanc, 54000 Nancy",
    latitude: 48.6960,
    longitude: 6.1830,
    starts_at: DateTime.new(2025, 12, 10, 14, 00),
    image_url: "https://images.unsplash.com/photo-1594708775432-840a187b5a14?q=80&w=800&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    description: <<-HTML
      Participez à un atelier pour donner une seconde vie à vos appareils, vêtements ou vélos. Des bénévoles experts sont là pour vous guider. C'est l'occasion idéale d'acquérir de nouvelles compétences et de lutter contre l'obsolescence programmée.

      ---

      **🚀 Et moi, comment je peux avoir le Déclic ?**
      Devenez bénévole réparateur : Si vous avez des compétences en électronique, couture, ou mécanique, proposez vos services. Sinon, venez avec un objet cassé et apprenez à le réparer !
    HTML
  },

  # --- Fiche 5 : Vélo-École (Écologiser) ---
  {
    title: "🚲 Vélo-École : Retrouvez l'équilibre et la confiance en Ville",
    category: "ecologiser",
    organization: "Association Velonomy",
    location: "Place de la République (Point de ralliement), 54000 Nancy",
    latitude: 48.6910,
    longitude: 6.1848,
    starts_at: DateTime.new(2026, 3, 15, 10, 00),
    image_url: "https://images.unsplash.com/photo-1532296410317-0d5880467140?q=80&w=800&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    description: <<-HTML
      Vous ne savez pas faire du vélo, ou vous n'êtes pas à l'aise dans la circulation ? La Vélo-École propose des cours pour adultes et enfants. L'objectif est de vous rendre autonome et de vous donner les clés pour circuler en sécurité, faisant du vélo un moyen de transport écologique et agréable.

      ---

      **🚀 Et moi, comment je peux avoir le Déclic ?**
      Apprenez à votre rythme : Inscrivez-vous à un cycle de cours. Vous pouvez aussi devenir moniteur bénévole pour partager votre passion du vélo et aider d'autres personnes à devenir autonomes.
    HTML
  },

  # --- Fiche 6 : Nuit de la Solidarité (Bénévolat) ---
  {
    title: "✨ La Nuit qui Compte : Recensement des Sans-Abris (22 Janvier)",
    category: "benevolat",
    organization: "Ville de Nancy / Atelier des Solidarités",
    location: "Atelier des Solidarités, 32 rue Sainte-Anne, 54000 Nancy",
    latitude: 48.6948,
    longitude: 6.1835,
    starts_at: DateTime.new(2026, 1, 22, 21, 00),
    image_url: "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=800&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    description: <<-HTML
      **Unissez vos forces avec les élus et travailleurs sociaux** le 22 janvier pour recenser les besoins des personnes sans domicile et améliorer les dispositifs d'aide.
      **Votre mission :** Aller à la rencontre des personnes sans domicile fixe pour comprendre leurs besoins.

      ---

      **🚀 Et moi, comment je peux avoir le Déclic ?**
      Devenez acteur de l'aide sociale : Votre temps et votre écoute sont les outils de cette nuit solidaire. Contactez L'Atelier des Solidarités pour vous inscrire à cette mission annuelle.
    HTML
  },

  # --- Fiche 7 : Épicerie Participative (Entreprendre) ---
  {
    title: "🥖 Ouvrez votre Épicerie Participative : Le modèle Monépi / Bouge ton coq",
    category: "entreprendre",
    organization: "Monépi / Bouge ton Coq",
    location: "Mairie de Landremont, 54700 Landremont (Modèle réussi)",
    latitude: 48.8687,
    longitude: 6.1438,
    starts_at: nil,
    image_url: "https://images.unsplash.com/photo-1506132717017-edb9c5132d73?q=80&w=800&auto=format&fit=crop",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    description: <<-HTML
      L'initiative "Monépi" cherche à revitaliser les zones rurales et péri-urbaines en créant des épiceries gérées collectivement par les habitants. Ce projet a permis de rouvrir un commerce essentiel, de créer du lien social et de soutenir les producteurs locaux.

      ---

      **🚀 Et moi, comment je peux avoir le Déclic ?**
      Portez un projet collectif : Contactez Monépi ou Bouge ton Coq pour initier la création d'une épicerie dans votre propre village ou quartier. Il faut un noyau de bénévoles motivés pour monter le projet.
    HTML
  },

  # --- OPPORTUNITÉ EXEMPLE 1 (Maraude - Gardée) ---
  {
    title: "Maraude Solidaire",
    category: "benevolat",
    organization: "Association X",
    location: "Place Stanislas, 54000 Nancy",
    latitude: 48.6930, longitude: 6.1830,
    starts_at: DateTime.new(2025, 12, 10, 20, 00),
    image_url: "https://images.unsplash.com/photo-1469571486292-0ba58a3f068b?q=80&w=800",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    description: "Apportez chaleur et écoute aux sans-abri lors d'une maraude en centre-ville. Chaque semaine, des bénévoles se relaient pour distribuer des repas chauds et du réconfort."
  },

  # --- OPPORTUNITÉ EXEMPLE 2 (Code - Gardée) ---
  {
    title: "Initiation au Code",
    category: "formation",
    organization: "Le Wagon / Epitech",
    location: "Rives de Meurthe, Nancy",
    latitude: 48.6960, longitude: 6.1950,
    starts_at: DateTime.new(2025, 12, 15, 18, 30),
    image_url: "https://images.unsplash.com/photo-1531482615713-2afd69097998?q=80&w=800",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    description: "Créez votre première page web en 2 heures. Ouvert aux débutants complets. Aucune connaissance préalable n'est requise. Venez avec votre ordinateur portable !"
  },

  # --- OPPORTUNITÉ EXEMPLE 3 (Jeux - Gardée) ---
  {
    title: "Soirée Jeux de Société",
    category: "rencontres",
    organization: "Médiathèque",
    location: "Médiathèque Manufacture, Nancy",
    latitude: 48.6980, longitude: 6.1750,
    starts_at: DateTime.new(2025, 12, 20, 14, 00),
    image_url: "https://images.unsplash.com/photo-1606167664536-e88102d512a1?q=80&w=800",
    is_active: true, # AJOUT DE LA CLÉ MANQUANTE
    description: "Venez partager un moment de convivialité autour d'un grand choix de jeux de société. Un événement régulier pour faire de nouvelles rencontres dans une ambiance décontractée."
  }
]

# Insertion des Opportunités
opportunities_data.each do |data|
  Opportunity.create!(data)
end


puts "✅ Opération terminée. 5 Stories et 8 Opportunities (dont 5 nouvelles Fiches Déclic) créées avec succès."
