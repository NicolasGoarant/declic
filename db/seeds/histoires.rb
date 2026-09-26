# 6 Belles Histoires : récits de parcours (aucun appel à l'action, aucun horaire), personnes fictives.
# 2 à 4 photos chacune ; la dernière est hors Métropole (test de la carte OpenStreetMap).
# Dates calculées à partir de Date.current.

def histoire(photos:, **attrs)
  fiche = Story.create!({ is_active: true, source_name: "Exemple - média local" }.merge(attrs))
  SeedsDemo.joindre_photos(fiche, photos)
  fiche
end

histoire(
  title: "Camille a fait de sa cour d'immeuble un jardin",
  thematique: "ecologiser", tags: "Végétalisation, Voisinage",
  happened_on: Date.current - 12, venue_name: "La cour des Fleurs", discover_url: "https://example.com/cour-des-fleurs",
  location: "8 rue de la Source, 54000 Nancy", address: "8 rue de la Source", city: "Nancy", postal_code: "54000",
  latitude: 48.6870, longitude: 6.1750,
  chapo: "Il y a deux ans, la cour de son immeuble n'était qu'une dalle de béton. Camille a commencé par un pot de menthe.",
  body: "Camille habite depuis dix ans au cœur de Nancy. Un matin, elle a posé un pot de menthe au pied du mur, juste pour voir.\n\n" \
        "Les voisins ont suivi : une jardinière, puis un bac de framboisiers, puis une pétition à la copropriété pour retirer quelques dalles. " \
        "Aujourd'hui, la cour compte une vingtaine de plantes, un petit potager et un banc où l'on se retrouve le soir.\n\n" \
        "Elle ne se prend pas pour une jardinière : « Je ne savais rien faire. J'ai demandé, essayé, raté, recommencé. »",
  points_forts: [ { "icone" => "feuille", "titre" => "Un premier pot suffit", "texte" => "Tout est parti d'un simple pot de menthe." },
                  { "icone" => "groupe", "titre" => "Les voisins se sont pris au jeu", "texte" => "Une vingtaine d'habitants participent aujourd'hui." },
                  { "icone" => "maison", "titre" => "La copropriété a dit oui", "texte" => "Quelques dalles retirées ont suffi à faire de la place." } ],
  quote: "Je ne savais rien faire. J'ai demandé, essayé, raté, recommencé.", quote_author: "Camille",
  source_url: "https://example.com/medias/cour-des-fleurs", source_published_on: Date.current - 40,
  photos: %w[cour1 cour2 vegetalisation]
)

histoire(
  title: "Sofiane cuisine les recettes de sa grand-mère pour les autres",
  thematique: "entreprendre", tags: "Cuisine, Traiteur, Reconversion",
  happened_on: Date.current - 25, venue_name: "La Table de Sofiane", discover_url: "https://example.com/table-de-sofiane",
  location: "8 rue des Ponts, 54000 Nancy", address: "8 rue des Ponts", city: "Nancy", postal_code: "54000",
  latitude: 48.6935, longitude: 6.1834,
  chapo: "Ancien magasinier, Sofiane est devenu traiteur en cuisinant, le soir, les plats de sa grand-mère pour ses collègues.",
  body: "Tout a commencé par un tajine apporté pour un pot de départ. Les collègues en redemandent, puis leurs familles.\n\n" \
        "Après un an de commandes au bouche-à-oreille, Sofiane suit une formation en hygiène, loue un labo partagé et déclare son activité. " \
        "Aujourd'hui, il livre des plateaux à vélo dans toute la Métropole.\n\n" \
        "Il garde un souvenir précis du premier client : « J'avais les mains qui tremblaient en rendant la monnaie. »",
  points_forts: [ { "icone" => "coeur", "titre" => "Une cuisine de famille", "texte" => "Les recettes viennent de sa grand-mère." },
                  { "icone" => "livre", "titre" => "Formé pas à pas", "texte" => "Une formation en hygiène avant de se lancer." },
                  { "icone" => "etoile", "titre" => "Le bouche-à-oreille", "texte" => "Les premiers clients sont d'anciens collègues." } ],
  quote: "J'avais les mains qui tremblaient en rendant la monnaie.", quote_author: "Sofiane",
  source_url: "https://example.com/medias/table-de-sofiane", source_published_on: Date.current - 60,
  photos: %w[art-culinaire fromagerie]
)

histoire(
  title: "Une salle de danse pour se faire des amis",
  thematique: "rencontres", tags: "Danse, Lien social",
  happened_on: Date.current - 40, venue_name: "MJC Lillebonne", discover_url: "https://example.com/mjc-lillebonne",
  location: "MJC Lillebonne, 14 rue du Cheval Blanc, 54000 Nancy", address: "14 rue du Cheval Blanc", city: "Nancy", postal_code: "54000",
  latitude: 48.6949, longitude: 6.1889,
  chapo: "Arrivée seule à Nancy pour son travail, Inès a poussé la porte d'un cours de salsa un jeudi soir.",
  body: "Inès ne connaissait personne dans la ville. Au premier cours, elle a marché sur les pieds de trois partenaires et ri comme jamais.\n\n" \
        "Elle est revenue la semaine suivante, puis a découvert la bachata, la kizomba, les soirées du samedi. " \
        "Un an plus tard, son cercle d'amis est né dans cette salle, et c'est elle qui accueille désormais les nouveaux.\n\n" \
        "Son conseil : « Ne pas attendre de bien danser pour venir. »",
  points_forts: [ { "icone" => "groupe", "titre" => "Une bande d'amis", "texte" => "Son cercle s'est construit au fil des cours." },
                  { "icone" => "coeur", "titre" => "Des soirées joyeuses", "texte" => "Salsa, bachata et kizomba selon l'humeur." },
                  { "icone" => "maison", "titre" => "Une MJC ouverte à tous", "texte" => "Aucune expérience de danse demandée." } ],
  quote: "Ne pas attendre de bien danser pour venir.", quote_author: "Inès",
  source_url: "https://example.com/medias/mjc-danse", source_published_on: Date.current - 75,
  photos: %w[salsa bachata kizomba]
)

histoire(
  title: "Léa, de la scène au tour de potier",
  thematique: "formation", tags: "Céramique, Reconversion, Art",
  happened_on: Date.current - 55, venue_name: "Atelier Terre & Feu", discover_url: "https://example.com/terre-et-feu",
  location: "12 rue des Michottes, 54000 Nancy", address: "12 rue des Michottes", city: "Nancy", postal_code: "54000",
  latitude: 48.6890, longitude: 6.1770,
  chapo: "Comédienne, Léa cherchait un métier des mains. Un stage d'un week-end a tout changé.",
  body: "Après des années de tournées, Léa voulait un rythme plus stable. Sur un coup de tête, elle s'est inscrite à un stage de céramique d'un week-end.\n\n" \
        "Elle a rejoint l'atelier comme apprentie, puis a passé un CAP. Elle vend aujourd'hui ses bols sur les marchés de la Métropole et enseigne le modelage le mercredi.\n\n" \
        "« La terre demande la même écoute qu'un partenaire de scène », sourit-elle.",
  points_forts: [ { "icone" => "goutte", "titre" => "Un stage, puis un métier", "texte" => "Un week-end d'initiation a suffi à lancer le projet." },
                  { "icone" => "livre", "titre" => "Un CAP en cours d'emploi", "texte" => "Formation passée sur deux ans." },
                  { "icone" => "coeur", "titre" => "Transmettre à son tour", "texte" => "Elle anime un atelier de modelage le mercredi." } ],
  quote: "La terre demande la même écoute qu'un partenaire de scène.", quote_author: "Léa",
  source_url: "https://example.com/medias/lea-ceramique", source_published_on: Date.current - 90,
  photos: %w[atelier1 atelier2 workshop-artistique]
)

histoire(
  title: "Un potager partagé pour se retrouver",
  thematique: "benevolat", tags: "Solidarité, Jardin, Alimentation",
  happened_on: Date.current - 70, venue_name: "Le potager de Boudonville", discover_url: "https://example.com/potager-boudonville",
  location: "Rue de Boudonville, 54000 Nancy", address: "Rue de Boudonville", city: "Nancy", postal_code: "54000",
  latitude: 48.6800, longitude: 6.1650,
  chapo: "Retraité, Gérard a découvert le bénévolat en donnant un coup de main à un potager solidaire. Il en est devenu le pilier.",
  body: "Quand Gérard a pris sa retraite, les journées lui ont paru longues. Un voisin lui a proposé de venir arroser au potager de Boudonville.\n\n" \
        "Les récoltes alimentent l'épicerie solidaire du quartier : courgettes, tomates et aromatiques atterrissent dans les paniers. " \
        "Gérard tient la permanence du samedi et forme les nouveaux venus.\n\n" \
        "« Je croyais que je donnais de mon temps, c'est moi qui ai reçu. »",
  points_forts: [ { "icone" => "feuille", "titre" => "Une récolte solidaire", "texte" => "Les légumes partent vers l'épicerie du quartier." },
                  { "icone" => "groupe", "titre" => "Un rendez-vous du samedi", "texte" => "Une équipe fidèle, ouverte aux nouveaux." },
                  { "icone" => "coeur", "titre" => "Un nouvel élan", "texte" => "Une retraite qui reprend du sens." } ],
  quote: "Je croyais que je donnais de mon temps, c'est moi qui ai reçu.", quote_author: "Gérard",
  source_url: "https://example.com/medias/potager-boudonville", source_published_on: Date.current - 100,
  photos: %w[jardin1 jardin2 serre canal1]
)

# Hors Métropole : teste la carte OpenStreetMap (hors emprise du diorama).
histoire(
  title: "Manon a transformé une ancienne ferme vosgienne en atelier partagé",
  thematique: "entreprendre", tags: "Artisanat, Ruralité, Atelier",
  happened_on: Date.current - 90, venue_name: "La Ferme des Ateliers", discover_url: "https://example.com/ferme-des-ateliers",
  location: "12 chemin des Prés, 88400 Gérardmer", address: "12 chemin des Prés", city: "Gérardmer", postal_code: "88400",
  latitude: 48.0737, longitude: 6.8783,
  chapo: "Originaire de Nancy, Manon a quitté la ville pour rouvrir une ferme à Gérardmer et y accueillir des artisans.",
  body: "Manon rêvait d'un lieu où les artisans travailleraient côte à côte. Elle a trouvé une ferme à l'abandon dans les Vosges.\n\n" \
        "Avec des amis, elle a restauré la grange, installé un four à céramique et un établi de menuiserie. " \
        "La ferme accueille aujourd'hui six artisans et un espace d'exposition ouvert le week-end.\n\n" \
        "« On n'a pas construit un atelier, on a construit une équipe. »",
  points_forts: [ { "icone" => "maison", "titre" => "Une ferme rouverte", "texte" => "Une grange à l'abandon devenue lieu de travail." },
                  { "icone" => "groupe", "titre" => "Six artisans", "texte" => "Céramique, bois et couture partagent le lieu." },
                  { "icone" => "etoile", "titre" => "Un espace d'exposition", "texte" => "Ouvert au public chaque week-end." } ],
  quote: "On n'a pas construit un atelier, on a construit une équipe.", quote_author: "Manon",
  source_url: "https://example.com/medias/ferme-des-ateliers", source_published_on: Date.current - 120,
  photos: %w[canal3 jardin2]
)
