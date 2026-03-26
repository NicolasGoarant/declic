# script/import_mjc.rb
# Usage : rails runner script/import_mjc.rb
# Importe les 10 fiches MJC Nancy (6 lieux + 4 spécifiques) dans Déclic.
# Les fiches existantes avec le même titre sont ignorées (idempotent).

FICHES = [

  # ─────────────────────────────────────────
  # FICHE 1 — MJC Desforges (lieu)
  # ─────────────────────────────────────────
  {
    title:         "MJC Desforges — 80 ans d'éducation populaire au cœur de Nancy",
    category:      "rencontres",
    organization:  "MJC Philippe Desforges",
    location:      "Nancy Centre",
    address:       "27 Rue de la République",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://www.mjc-desforges.com",
    contact_phone: "03 83 27 40 53",
    contact_email: "contact@mjc-desforges.com",
    source_name:   "mjc-desforges.com",
    source_url:    "https://www.mjc-desforges.com",
    time_commitment: "Selon l'activité choisie",
    is_active:     true,
    tags:          "MJC, culture, musique, danse, jeunesse, éducation populaire, Nancy centre",
    stat_1_number: "1945", stat_1_label: "Année de création",
    stat_2_number: "250",  stat_2_label: "Élèves à l'école de musique",
    stat_3_number: "15",   stat_3_label: "Professeurs de musique",
    stat_4_number: "60",   stat_4_label: "Places à L'Audito",
    description: <<~MD,
      La **MJC Philippe Desforges** célèbre cette saison ses **80 ans**. Fondée en 1945, elle est la plus ancienne MJC encore en activité à Nancy — et son énergie n'a pas faibli. Rue de la République, en plein centre-ville, elle accueille chaque semaine des centaines d'adhérent·es de tous âges.

      ## Ce que tu y trouveras

      **L'École de musique** réunit environ 250 élèves encadrés par 15 professeurs. Elle couvre un éventail remarquable de styles : du classique au jazz, du gospel aux musiques latines, en passant par le rock et les musiques du monde. Les cours individuels (piano, guitare, batterie, violon, saxo, chant, accordéon…) s'articulent avec des ateliers collectifs — Big Band, atelier jazz, atelier latino, pop/rock kids et ados — et une formation musicale (solfège).

      **L'Audito** est la salle de spectacle maison : 60 places en arc de cercle autour de la scène, une acoustique intimiste, et un projet clair — accompagner la scène émergente locale. Résidences de création, coaching scénique, captations, concerts sans restriction de style.

      Les **activités arts, expression & loisirs** sont tout aussi riches : danse classique, hip-hop, waacking, bachata dominicaine, danse orientale, danse moderne jazz ; arts plastiques (dessin, modelage, couture, atelier terre, peinture) ; langue anglaise et espagnole ; sports & détente (pilates, yoga, gym, qi-gong, zumba, sophrologie…).

      La **Bibliothèque jeunesse** (avec club jeux de rôle) et le **Centre de loisirs** mercredis et petites vacances (3–12 ans) complètent l'offre.

      ## Vie associative

      Des associations sont accueillies dans les locaux : Ligue des droits de l'Homme, Les Semeuses (AMAP), Radio Club F6KIM, Association France-Japon, SOS Amitié, Esperanto Nancy…

      ## Horaires

      Hors vacances scolaires : Lun 9h–13h | Mar 10h–13h / 14h–19h | Mer 9h–12h | Jeu 9h30–13h / 14h–19h30 | Ven 10h–13h / 14h–18h30.
      Activités : ouvertes lun–ven de 8h30 à 22h.

      ## Adhésion

      9 € / an, valable dans les 6 autres MJC de Nancy.
    MD
  },

  # ─────────────────────────────────────────
  # FICHE 2 — MJC Beauregard (lieu)
  # ─────────────────────────────────────────
  {
    title:         "MJC Beauregard — La maison de quartier ouverte à toutes et tous",
    category:      "rencontres",
    organization:  "MJC Beauregard",
    location:      "Quartier Beauregard, Nancy",
    address:       "Place Maurice Ravel",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://www.mjcbeauregard.fr",
    contact_phone: "03 83 96 39 70",
    contact_email: "contact@mjcbeauregard.fr",
    source_name:   "mjcbeauregard.fr",
    source_url:    "https://www.mjcbeauregard.fr",
    time_commitment: "Selon l'activité choisie",
    is_active:     true,
    tags:          "MJC, culture, sport, danse, musique, FLE, jeunesse, Beauregard, Nancy",
    stat_1_number: "9",  stat_1_label: "€/an (adhésion annuelle)",
    stat_2_number: "5",  stat_2_label: "Niveaux de cours FLE gratuits",
    stat_3_number: "34", stat_3_label: "Séances par activité (base annuelle)",
    description: <<~MD,
      Installée **Place Maurice Ravel**, dans le quartier Beauregard, la **MJC Beauregard** est un équipement socioculturel de proximité porté par des bénévoles et des professionnels engagés. Accessible en bus (T4 — arrêts Beauregard / Sainte-Anne), elle ouvre ses portes du lundi au samedi.

      ## Les ateliers 2025/2026

      **Sports & détente** : bodyrelax, circuit training, footing (gratuit, adhésion seule), gym douce, gym d'entretien, pilates (plusieurs créneaux + pilates fusion), qi gong, renforcement musculaire, barre au sol, sophrologie, yoga postural, yoga (hatha), zumba, stretching.

      **Musique** : guitare acoustique et électrique, piano classique et jazz, batterie. Auditions et gala en fin d'année.

      **Danse** : éveil à la danse (3–5 ans), danse classique, danse jazz (initiation, kids, teens). Gala annuel.

      **Arts & expressions** : arts du cirque (+6 ans), aquarelle, couture, atelier Lego, théâtre adultes, théâtre enfants.

      **Et aussi** : AMAP de la Vallotte (mar et ven 18h30–20h), Repair Café (1 samedi/mois), soirées "Rencontres et Partage" tout au long de l'année.

      ## Point fort : les cours de Français Langue Étrangère (FLE)

      Depuis une dizaine d'années, la MJC Beauregard propose des **cours de français entièrement gratuits** pour toute personne majeure souhaitant apprendre ou progresser — une offre rare et précieuse à Nancy.

      ## Centre de loisirs

      Mercredis (3–11 ans), 8h–18h30. Tarifs modulés selon quotient familial.

      ## Horaires d'accueil

      Lun–jeu 9h–12h30 / 13h30–18h | Ven 9h–12h30 / 13h30–17h. La MJC est ouverte du lundi au samedi dès 9h jusqu'à la fin des activités.
    MD
  },

  # ─────────────────────────────────────────
  # FICHE 3 — MJC Haut-du-Lièvre (lieu)
  # ─────────────────────────────────────────
  {
    title:         "MJC Haut-du-Lièvre — Agitatrice de culture sur le Plateau de Haye",
    category:      "rencontres",
    organization:  "MJC Haut-du-Lièvre",
    location:      "Plateau de Haye, Nancy",
    address:       "854 Avenue Raymond Pinchard",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://mjc-hdl.com",
    contact_phone: "03 83 96 54 11",
    contact_email: "contact@mjc-hdl.com",
    source_name:   "mjc-hdl.com",
    source_url:    "https://mjc-hdl.com",
    time_commitment: "Selon l'activité choisie",
    is_active:     true,
    tags:          "MJC, Haut-du-Lièvre, Plateau de Haye, culture, danse, musique, studio, jeunesse",
    stat_1_number: "1966", stat_1_label: "Année de fondation",
    stat_2_number: "5",    stat_2_label: "€/h (studio de répétition)",
    stat_3_number: "10",   stat_3_label: "€/h (studio d'enregistrement)",
    stat_4_number: "8",    stat_4_label: "€/an (adhésion)",
    description: <<~MD,
      Sur le **Plateau de Haye**, la **MJC Haut-du-Lièvre** est ancrée dans son quartier depuis 1966. Association loi 1901 agréée Jeunesse et Éducation Populaire, elle dispose d'une salle de spectacle, de deux studios ouverts à tous, et d'une programmation éclectique.

      ## Activités 2025/2026

      **Sports** : remise en forme (22€/séance, tout public), futsal enfants (mar et/ou jeu 17h45–18h45), stretching adultes (mar 12h30–13h30 et ven 11h–12h).

      **Danses** : danse afro (enfants ven 17h30–18h30 / adultes 19h–20h30), hip-hop (enfants mar 17h–18h / adultes mar 18h30–20h), danse arménienne (tous niveaux), danse géorgienne enfants.

      **Autres** : club d'échecs (mer 13h30–14h30), e-sport (lun 17h30–18h30), accompagnement scolaire (aide aux devoirs).

      ## Studios à disposition

      - **Studio de répétition** — insonorisé, matériel fourni, **5 €/h**, lun–ven 9h–21h
      - **Studio d'enregistrement** — conditions pro, **10 €/h**, lun–ven 14h–21h
      - **Atelier réparation vélo** — main d'œuvre gratuite, lun–ven

      ## Salle de spectacle

      Grande salle accueillant représentations théâtrales, concerts, scènes ouvertes, projections et débats.

      ## Accueil & horaires

      Mar–ven 9h–12h et 13h–18h30. Bus : T2 et 13, arrêt Cèdre Bleu.
    MD
  },

  # ─────────────────────────────────────────
  # FICHE 4 — MJC 3 Maisons (lieu)
  # ─────────────────────────────────────────
  {
    title:         "MJC 3 Maisons — Cirque, jonglerie et jardin partagé quartier des 3 Maisons",
    category:      "rencontres",
    organization:  "MJC 3 Maisons",
    location:      "Quartier des 3 Maisons, Nancy",
    address:       "12 rue de Fontenoy",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://www.mjc3maisons.fr",
    contact_phone: "03 83 32 80 52",
    contact_email: "contact@mjc3maisons.fr",
    source_name:   "mjc3maisons.fr",
    source_url:    "https://www.mjc3maisons.fr",
    time_commitment: "Selon l'activité choisie",
    is_active:     true,
    tags:          "MJC, culture, danse, théâtre, cirque, musique, jardin, jonglerie, Nancy",
    stat_1_number: "15",  stat_1_label: "à 20 groupes musicaux accueillis/an",
    stat_2_number: "10",  stat_2_label: "Ans que le jardin partagé anime le quartier",
    stat_3_number: "12",  stat_3_label: "e édition de la Convention Bibasse (mai 2026)",
    stat_4_number: "9",   stat_4_label: "€/an (adhésion)",
    description: <<~MD,
      La **MJC 3 Maisons** est connue pour son effervescence culturelle — festivals, jardin partagé, programmation musicale et scénique de qualité. Elle est installée dans le quartier du même nom, au nord de Nancy.

      ## Les activités 2025/2026

      **Danses** : modern'jazz (éveil 4–5 ans jusqu'aux adultes), swing / lindy hop / charleston (3 niveaux + solo swing), flamenco (4 niveaux avec A Compás), K-pop (dimanche matin), hip-hop, danse de salon (nouveauté).

      **Théâtre** : théâtre adultes et enfants/ados, impro adultes et ados, stages clown.

      **Arts** : photo numérique et argentique (nouveauté), BD & manga, arts visuels enfants, atelier cinéma (nouveauté), atelier Lego, couture, écriture créative.

      **Sports** : yoga (adultes, enfants, parents-enfants — nouveauté), pilates, gym tonic, gym douce, multi-sports enfants, aïkido, karaté (6–16 ans), tai-chi-chuan, body sculpt, marches urbaines (nouveauté).

      **Cirque** : initiation aux arts du cirque (4–14 ans), rendez-vous jonglage (dimanche, 9€/an).

      **Musique** : guitare, batterie, piano, contrebasse, chant, chorale, ateliers musiques actuelles.

      **Jardin partagé** : ouvert toute l'année, potager naturel, ateliers nature avec enfants, hamacs, pétanque, molky.

      ## Les grands événements

      - **Convention Bibasse** (12e éd.) — festival de jonglerie, 13–17 mai 2026
      - **Le Palace** — fête de quartier d'hiver, balade lumineuse + banquet, 14 mars 2026
      - **Fête du jardin** — dimanche 7 juin 2026

      ## Local de répétition en auto-gestion

      Un local dédié aux groupes de musique dans le bâtiment "Cube" — entre 15 et 20 groupes accueillis par saison. L'esprit garage assumé.

      ## Horaires

      Lun–jeu 9h–12h / 14h–21h | Ven 9h–12h / 14h–19h. Bus : lignes 12 et 13, arrêt MJC 3 Maisons.
    MD
  },

  # ─────────────────────────────────────────
  # FICHE 5 — MJC Bazin (lieu)
  # ─────────────────────────────────────────
  {
    title:         "MJC Bazin — La maison de quartier vivante depuis 1973",
    category:      "rencontres",
    organization:  "MJC Bazin",
    location:      "Nancy, quartier Saint-Max / canal",
    address:       "47 rue Henri Bazin",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://www.mjcbazin.com",
    contact_phone: "03 83 36 56 65",
    contact_email: "info@mjcbazin.com",
    source_name:   "mjcbazin.com",
    source_url:    "https://www.mjcbazin.com",
    time_commitment: "Selon l'activité choisie",
    is_active:     true,
    tags:          "MJC, danse, théâtre, impro, arts, sport, Bazin, Nancy",
    stat_1_number: "1973", stat_1_label: "Année de création",
    stat_2_number: "40",   stat_2_label: "Intervenants actifs",
    stat_3_number: "9",    stat_3_label: "€/an (adhésion, valable dans les 7 MJC)",
    description: <<~MD,
      La **MJC Bazin** — "espace de vie partagé depuis 1973" — est une maison à taille humaine, avec une quarantaine d'intervenants et une programmation dense. Accessible depuis la ligne T1 (arrêt Deux Rives – Olympe de Gouges) et la ligne 13.

      ## Les activités 2025/2026

      **Détente & bien-être** : sophrologie, relaxation et mouvement, hatha yoga, qi gong, tai-chi-chuan, pilates, sport-santé, yoga-pilates, step, fit boxing, yin yoga (nouveauté), hata yoga (nouveauté).

      **Sport** : gym enfants (3–8 ans), gym adultes (body sculpt, cardio sculpt, circuit training, step, zumba, strong nation, fit boxing, gym douce), skate board (8–12 ans et +13 ans), roller enfants et adultes.

      **Danses** : modern'jazz enfants et adultes, hip-hop / break dance, danse africaine avec musiciens live, flamenco (4 niveaux + pataitas de tangos), danses orientales (2 niveaux), salsa cubaine, danse indienne bollywood et traditionnelle (nouveauté), danse de salon, thé dansant "amidanse" (ven 14h–17h, 4,50€/séance).

      **Théâtre & impro** : théâtre adultes, théâtre enfants et ados, impro adultes (débutants / initiés), impro ados, stages clown.

      **Arts & expressions** : peinture et techniques mixtes, dessin, aquarelle, atelier terre (Nicolas Carlin), couture, linogravure, graff / street art, atelier d'écriture (nouveauté), peinture chinoise, manga enfants (nouveauté), manga / BD / caricatures, arts plastiques enfants et ados, photo numérique, jardinage et nature en ville.

      **Gourmandises** : cuisine du monde (10 séances), oenologie, club de dégustation whisky (nouveauté).

      **Langues** : anglais enfants et adultes, espagnol, italien.

      ## Les grands événements 2025/2026

      - **GIF Festival** — 21–23 novembre 2025 (festival d'impro)
      - **Festival "Sous le sapin"** — 12–21 décembre 2025
      - **Festival Trash & drôle mais pas que…** — 23–25 janvier 2026
      - **Restaurant éphémère** — 14 mars et 4 juillet 2026 (30€/pers., sur réservation)
      - Expositions tout au long de l'année

      ## Horaires

      Accueil : lun 9h–12h / 17h–21h | mar–ven 9h–12h / 14h–21h | sam 9h–13h.
      Bus : T1 arrêt Deux Rives – Olympe de Gouges | ligne 13.
    MD
  },

  # ─────────────────────────────────────────
  # FICHE 6 — MJC Lillebonne (lieu)
  # ─────────────────────────────────────────
  {
    title:         "MJC Lillebonne — Une fourmilière d'activités en plein cœur de Nancy",
    category:      "rencontres",
    organization:  "MJC Lillebonne Saint-Épvre",
    location:      "Nancy Centre / Vieille Ville",
    address:       "14 rue du Cheval Blanc",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://www.mjclillebonne.fr",
    contact_phone: "03 83 36 82 82",
    contact_email: "contact@mjclillebonne.fr",
    source_name:   "mjclillebonne.fr",
    source_url:    "https://www.mjclillebonne.fr",
    time_commitment: "Selon l'activité choisie",
    is_active:     true,
    tags:          "MJC, art contemporain, musique, danse, photo, théâtre, langues, Lillebonne, Nancy",
    stat_1_number: "1984", stat_1_label: "Année d'ouverture de la Galerie Lillebonne",
    stat_2_number: "100",  stat_2_label: "Activités proposées",
    stat_3_number: "9",    stat_3_label: "€/an (adhésion, valable dans les 7 MJC)",
    description: <<~MD,
      La **MJC Lillebonne Saint-Épvre** est nichée dans un bâtiment classé du patrimoine historique nancéien, rue du Cheval Blanc. Plus d'une centaine d'activités, une galerie d'art contemporain ouverte depuis 1984, une école des musiques complète, et une programmation événementielle qui en font un vrai lieu de vie culturelle.

      ## L'École des musiques

      Un éventail exceptionnel : batterie, chant, clarinette, contrebasse, flûte, guitare basse et classique, jazz, hautbois, percussions, piano classique et jazz, saxophone, trombone, trompette, violon, violoncelle. Formation musicale en 5 niveaux, ateliers collectifs (La Fanfarone, Le Gâteau sur la Cerise, la Petite Fanfare, Combos Jazz…), scènes ouvertes tout au long de l'année. Studio d'enregistrement "Good Island" disponible.

      ## Arts plastiques & création

      Dessin / BD, modelage / sculpture anatomique, couture, gravure (Atelier en Archipel), sérigraphie, sketching, typographie manuelle, photo argentique ("Labotomie" — labo expérimental avec accès libre) et numérique, reliure, calligraphie (latine + arabe en partenariat avec l'ATMF et Diwan en Lorraine).

      ## Danses et théâtre

      Hip-hop (Association Street Harmony), contact impro, danses d'Afrique de l'Ouest (avec musiciens live), danse classique, moderne jazz, de salon, égyptienne. Théâtre adultes (initiation + création), théâtre d'improvisation, théâtre recherche & création.

      ## Sports & détente

      Aïkido, escalade, gym douce / relaxation, judo / ju-jitsu, pilates, plongée sous-marine, sin-moo-hapkido, tai-ji-quan / qi gong / méditation taoïste, tissu aérien / trapèze, yoga, ninjutsu.

      ## Langues & gourmandises

      Arabe, chinois, espagnol, FLE (9€ adhésion, cours gratuits), italien, japonais, polonais, russe (7 niveaux). Cuisine japonaise, chinoise, russe, végétarienne indienne. Oenologie (8 séances).

      ## Horaires

      Période scolaire : lun–ven 8h30–23h | sam 8h30–18h.
      Accueil : lun 14h–20h | mar–ven 8h30–12h30 / 13h30–23h | sam 8h30–18h.
      Bus : place Carnot (10, 12, 13, 16) | Bibliothèque (T2, T3, T4, 11, 15) | arrêt St-Épvre (Citadine 1).
    MD
  },

  # ─────────────────────────────────────────
  # FICHE 7 — FLE Beauregard (spécifique)
  # ─────────────────────────────────────────
  {
    title:         "Apprendre le français gratuitement — Cours FLE à la MJC Beauregard",
    category:      "formation",
    organization:  "MJC Beauregard — Section FLE",
    location:      "Quartier Beauregard, Nancy",
    address:       "Place Maurice Ravel",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://www.mjcbeauregard-fle.fr",
    contact_phone: "03 83 96 39 70",
    contact_email: "contact@mjcbeauregard.fr",
    source_name:   "Programme MJC Beauregard 2025/2026",
    source_url:    "https://www.mjcbeauregard.fr",
    time_commitment: "4 matins par semaine (lun, mar, jeu, ven), hors vacances scolaires",
    is_active:     true,
    tags:          "FLE, français, langue étrangère, intégration, bénévolat, formation, gratuit, Beauregard",
    stat_1_number: "5",  stat_1_label: "Niveaux (du grand débutant au confirmé)",
    stat_2_number: "0",  stat_2_label: "€ de frais de cours (entièrement gratuit)",
    stat_3_number: "9",  stat_3_label: "€/an (adhésion MJC, seul frais)",
    quote:         "On peut s'inscrire n'importe quand dans l'année. Il n'y a pas de mauvais moment pour commencer.",
    quote_author:  "MJC Beauregard",
    description: <<~MD,
      Depuis une dizaine d'années, la **MJC Beauregard** propose l'un des dispositifs d'apprentissage du français les plus accessibles de Nancy : des **cours de Français Langue Étrangère (FLE) entièrement gratuits**, ouverts à toute personne majeure souhaitant apprendre ou progresser. Les cours sont animés par des formateurs bénévoles.

      ## Comment ça fonctionne ?

      Les cours ont lieu **4 matins par semaine** (lundi, mardi, jeudi, vendredi), hors vacances scolaires :

      - **9h00 à 10h30** — certains niveaux
      - **10h45 à 12h15** — autres niveaux

      Les apprenants sont répartis en **5 niveaux**, du grand débutant (sans aucune connaissance du français) au niveau confirmé.

      Des activités culturelles gratuites sont organisées certains après-midis.

      ## Inscription

      Inscriptions pour la rentrée 2025/2026 : du lundi 8 au vendredi 12 septembre 2025 (sauf mer 10/09), de 9h15 à 11h45.
      Début des cours : lundi 15 septembre 2025. Inscription préalable obligatoire.

      **On peut rejoindre les cours à n'importe quel moment de l'année.**

      Seul frais : adhésion annuelle de **9 €** à la MJC.

      ## Tu veux devenir formateur bénévole ?

      La section FLE accueille régulièrement de nouveaux bénévoles pour encadrer les groupes. Contacte la MJC au 03 83 96 39 70.
    MD
  },

  # ─────────────────────────────────────────
  # FICHE 8 — Studios MJC Haut-du-Lièvre (spécifique)
  # ─────────────────────────────────────────
  {
    title:         "Studios de musique ouverts à tous — MJC Haut-du-Lièvre",
    category:      "rencontres",
    organization:  "MJC Haut-du-Lièvre",
    location:      "Plateau de Haye, Nancy",
    address:       "854 Avenue Raymond Pinchard",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://mjc-hdl.com",
    contact_phone: "03 83 96 54 11",
    contact_email: "contact@mjc-hdl.com",
    source_name:   "Programme MJC HdL 2025/2026",
    source_url:    "https://mjc-hdl.com",
    time_commitment: "À la carte, sur réservation",
    is_active:     true,
    tags:          "studio, musique, répétition, enregistrement, Haut-du-Lièvre, abordable, Nancy",
    stat_1_number: "5",  stat_1_label: "€/h — studio de répétition",
    stat_2_number: "10", stat_2_label: "€/h — studio d'enregistrement",
    stat_3_number: "12", stat_3_label: "heures d'ouverture quotidienne (9h–21h)",
    quote:         "Un accompagnement possible pour vous guider dans vos projets.",
    quote_author:  "MJC Haut-du-Lièvre",
    description: <<~MD,
      Sur le **Plateau de Haye**, la MJC Haut-du-Lièvre met à disposition deux studios accessibles sur réservation — l'une des offres les plus abordables de Nancy pour les musiciens, amateur·es ou semi-professionnel·les.

      ## Studio de répétition — 5 €/h

      Espace insonorisé, avec tout le matériel nécessaire, pour répéter en solo ou en groupe.

      - **Tarif** : 5 €/h
      - **Horaires** : lundi au vendredi, 9h–21h
      - **Réservation** : contacter l'accueil de la MJC

      ## Studio d'enregistrement — 10 €/h

      Environnement professionnel pour enregistrer tes morceaux dans de bonnes conditions, que tu sois débutant·e ou musicien·ne confirmé·e.

      - **Tarif** : 10 €/h
      - **Horaires** : lundi au vendredi, 14h–21h
      - **Réservation** : contacter l'accueil de la MJC

      ## Bonus : atelier de réparation vélo

      Main d'œuvre gratuite, seules les pièces sont facturées. Ouvert du lundi au vendredi.

      ## Accès

      Adhésion MJC : 8 € / personne. Bus : T2 et 13, arrêt Cèdre Bleu. Accueil : mar–ven 9h–12h et 13h–18h30.
    MD
  },

  # ─────────────────────────────────────────
  # FICHE 9 — Local répétition MJC 3 Maisons (spécifique)
  # ─────────────────────────────────────────
  {
    title:         "Local de répétition en auto-gestion — MJC 3 Maisons",
    category:      "rencontres",
    organization:  "MJC 3 Maisons",
    location:      "Quartier des 3 Maisons, Nancy",
    address:       "12 rue de Fontenoy",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://www.mjc3maisons.fr",
    contact_phone: "03 83 32 80 52",
    contact_email: "contact@mjc3maisons.fr",
    source_name:   "Programme MJC 3 Maisons 2025/2026",
    source_url:    "https://www.mjc3maisons.fr",
    time_commitment: "Aux horaires d'ouverture de la MJC",
    is_active:     true,
    tags:          "musique, répétition, studio, groupe, auto-gestion, 3 Maisons, Nancy",
    stat_1_number: "15", stat_1_label: "à 20 groupes accueillis régulièrement par an",
    stat_2_number: "9",  stat_2_label: "€/an (adhésion MJC — seul frais)",
    quote:         "Un lieu un peu garage où tout semble encore possible.",
    quote_author:  "MJC 3 Maisons",
    description: <<~MD,
      Dans le bâtiment "Cube" de la **MJC 3 Maisons**, un local de répétition fonctionne en **auto-gestion** depuis plusieurs années. Entre 15 et 20 groupes de musique y travaillent régulièrement chaque saison.

      ## L'esprit du lieu

      Le local n'a pas la rigueur d'un studio commercial. C'est un espace de travail pour s'essayer, expérimenter, faire ensemble — sans la pression du minutage. L'auto-gestion implique que les groupes organisent eux-mêmes leurs créneaux. Tous styles confondus.

      ## Comment en bénéficier ?

      Contacte la MJC directement pour connaître les modalités d'accueil et les créneaux disponibles.

      Adhésion annuelle : 9 € (valable dans les 7 MJC de Nancy).
      Bus : lignes 12 et 13, arrêt MJC 3 Maisons.
      Horaires MJC : lun–jeu 9h–12h / 14h–21h | ven 9h–12h / 14h–19h.
    MD
  },

  # ─────────────────────────────────────────
  # FICHE 10 — Galerie Lillebonne (spécifique)
  # ─────────────────────────────────────────
  {
    title:         "Galerie Lillebonne — Art contemporain dans une MJC depuis 1984",
    category:      "rencontres",
    organization:  "MJC Lillebonne — Galerie Lillebonne",
    location:      "Nancy Centre / Vieille Ville",
    address:       "14 rue du Cheval Blanc",
    city:          "Nancy",
    postal_code:   "54000",
    website:       "https://www.mjclillebonne.fr",
    contact_phone: "03 83 36 82 82",
    contact_email: "galerielillebonne@mjclillebonne.fr",
    source_name:   "Programme MJC Lillebonne 2025/2026",
    source_url:    "https://www.mjclillebonne.fr",
    time_commitment: "Entrée libre aux expositions",
    is_active:     true,
    tags:          "art contemporain, galerie, exposition, résidence, médiation, Lillebonne, Nancy",
    stat_1_number: "1984", stat_1_label: "Année d'ouverture de la galerie",
    stat_2_number: "0",    stat_2_label: "€ (entrée libre aux expositions)",
    description: <<~MD,
      La **Galerie Lillebonne** est un cas rare dans le paysage culturel nancéien : une galerie d'art associative, installée depuis **1984** au sein d'une MJC, avec une triple mission — diffusion de la création contemporaine, formation des publics, soutien aux artistes.

      ## Un espace qui surprend

      Nichée dans un bâtiment classé du centre historique de Nancy, la galerie accueille chaque saison plusieurs expositions, souvent issues de cultures émergentes ou de démarches militantes. Les artistes trouvent aussi un espace de résidence : ils préparent une étape de leur travail en cohabitation avec les activités de la MJC.

      ## La programmation 2025/2026

      - **"Plume et Plomb"** — Claire Cordel, artiste plasticienne | 26 sept. – 8 nov. 2025
      - **"À contre nuit"** — VerOblanchot, expo photos | 16 jan. – 20 fév. 2026 (avec performances dansées)
      - **"Souvenirs"** — Camille Hofmann, céramiste | 13 mars – 17 avril 2026

      ## Infos pratiques

      Galerie ouverte selon le calendrier des expositions : **mar–sam 14h–19h** et sur rendez-vous.
      Contact : galerielillebonne@mjclillebonne.fr — Entrée libre.
    MD
  },

].freeze

# ─────────────────────────────────────────
# IMPORT
# ─────────────────────────────────────────

puts "\n=== Import MJC Nancy — #{FICHES.size} fiches ==="
puts "Environnement : #{Rails.env}\n\n"

created_count  = 0
skipped_count  = 0
error_count    = 0

FICHES.each_with_index do |attrs, i|
  if Opportunity.exists?(title: attrs[:title])
    puts "  [#{i + 1}/#{FICHES.size}] ⏭  IGNORÉE (existe déjà) : #{attrs[:title].truncate(70)}"
    skipped_count += 1
    next
  end

  opp = Opportunity.new(attrs)

  if opp.save
    puts "  [#{i + 1}/#{FICHES.size}] ✅ CRÉÉE : #{attrs[:title].truncate(70)}"
    created_count += 1
  else
    puts "  [#{i + 1}/#{FICHES.size}] ❌ ERREUR : #{attrs[:title].truncate(70)}"
    opp.errors.full_messages.each { |msg| puts "       → #{msg}" }
    error_count += 1
  end
end

puts "\n=== Résultat ==="
puts "  ✅ Créées  : #{created_count}"
puts "  ⏭  Ignorées : #{skipped_count}"
puts "  ❌ Erreurs  : #{error_count}"
puts "\nN'oublie pas de lancer le géocodage :"
puts "  rails runner \"Opportunity.where(latitude: nil).find_each { |o| o.geocode; o.save(validate: false) }\""
