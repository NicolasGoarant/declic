# db/seeds.rb

puts "🧹 Nettoyage de la base de données..."
Story.destroy_all
Opportunity.destroy_all

# ==============================================================================
# 1. LES BELLES HISTOIRES (STORIES)
# ==============================================================================
puts "📖 Création des Belles Histoires (Presse)..."

stories_data = [
  {
    title: "Elle plaque la finance à Paris pour devenir fromagère affineuse",
    chapo: "Bénédicte a troqué ses fichiers Excel contre des tomes de fromage. Un retour aux sources et au terroir nancéien pour retrouver du sens.",
    location: "21 Grande Rue, 54000 Nancy",
    latitude: 48.6936, longitude: 6.1832,
    happened_on: Date.new(2023, 6, 3),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?q=80&w=1600&auto=format&fit=crop",
    body: <<~MARKDOWN
      ### Le Profil
      Bénédicte, 33 ans, avait une carrière toute tracée dans le marketing et la finance à Paris. Mais passer 10 heures par jour derrière un ordinateur ne lui suffisait plus. Elle cherchait du sens, du partage, et surtout à se rapprocher de sa famille et de ses racines nancéiennes.

      ### Le Déclic
      Le besoin de "changer de vie" s'est imposé comme une nécessité vitale. Elle ne voulait plus d'un métier virtuel. Elle a donc démissionné pour se lancer dans un "tour de France" de l'apprentissage : un an de formation auprès de fromagers affineurs, complété par des stages intensifs pour maîtriser le produit.

      ### L'Action
      Bénédicte a jeté son dévolu sur une ancienne librairie de la Vieille Ville pour ouvrir **Caseus**. Après deux mois de travaux, elle a créé un lieu hybride : une crèmerie-fromagerie qui fait la part belle aux producteurs locaux (comme la laiterie de Manoncourt-en-Vermois). Elle y a même installé des tables pour déguster des planches sur place, recréant ce lien social qui lui manquait tant.

      ### Si vous voulez faire comme Bénédicte
      Vous visez un métier de bouche ?
      * **Formez-vous sur le terrain :** Bénédicte a passé 1 an à apprendre le métier chez des maîtres affineurs avant d'ouvrir. C'est indispensable pour la crédibilité.
      * **Le sourcing est clé :** Elle connaît personnellement ses producteurs (Jura, Auvergne, Lorraine). Allez à la rencontre de ceux qui fabriquent !
      * **Innovez :** Elle ne vend pas juste du fromage, elle propose une expérience (dégustation sur place, recettes créatives).
    MARKDOWN
  },
  {
    title: "Il ramène la campagne en ville avec sa laiterie urbaine",
    chapo: "Matthieu voulait produire de ses mains. Il a installé une véritable laiterie en plein centre-ville pour offrir du 100% local aux citadins.",
    location: "6 rue Saint-Nicolas, 54000 Nancy",
    latitude: 48.6885, longitude: 6.1852,
    happened_on: Date.new(2023, 4, 8),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1629198688000-71f23e745b6e?q=80&w=1600&auto=format&fit=crop",
    body: <<~MARKDOWN
      ### Le Profil
      Matthieu, trentenaire, travaillait dans la grande distribution. Une situation stable, mais qui a perdu son sens suite à la crise du Covid. Il a ressenti le besoin impérieux de "retourner à l'école" pour apprendre un savoir-faire manuel et concret.

      ### Le Déclic
      Son projet a mûri pendant deux ans. Il a quitté son poste pour passer un BTS Agricole spécialité "fromage" en Franche-Comté. Son ambition ? Casser les codes et prouver qu'on peut produire, transformer et vendre au même endroit, même en plein centre-ville.

      ### L'Action
      Il a transformé une cellule commerciale rue Saint-Nicolas en un véritable laboratoire aux normes sanitaires strictes. Matthieu ne se contente pas de vendre : il fabrique sur place ses yaourts et fromages (Tome de Nancy, type Morbier...) à partir de lait bio collecté à Royaumeix. Il offre ainsi aux citadins du "100% local" avec zéro intermédiaire.

      ### Si vous voulez faire comme Matthieu
      Le concept de "production urbaine" vous tente ?
      * **La réglementation d'abord :** Transformer un local commercial en site de production alimentaire demande une maîtrise parfaite des normes d'hygiène.
      * **La transparence :** Le laboratoire de Matthieu est visible. Montrer que vous "faites" est votre meilleur atout marketing.
      * **La matière première :** Tout repose sur la qualité de votre partenaire agricole. Soignez cette relation.
    MARKDOWN
  },
  {
    title: "De la fonction publique au Coffee Shop : le pari d'Aude",
    chapo: "Ancienne professeure puis fonctionnaire, Aude a profité du confinement pour réaliser son rêve d'ouvrir un café, épaulée par une franchise.",
    location: "Rue des Ponts, 54000 Nancy",
    latitude: 48.6875, longitude: 6.1820,
    happened_on: Date.new(2021, 12, 14),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=1600&auto=format&fit=crop",
    body: <<~MARKDOWN
      ### Le Profil
      Aude, 29 ans, a d'abord été professeure des écoles, puis fonctionnaire dans un lycée (gestion du bac et de la cantine). Un parcours dans le service public qui ne laissait pas présager un avenir de commerçante.

      ### Le Déclic
      C'est le confinement qui a servi de catalyseur. "C'était le moment ou jamais, j'avais encore l'énergie de me lancer". Elle a réalisé que son rêve d'ouvrir un café, enfoui depuis longtemps, devait se concrétiser maintenant.

      ### L'Action
      Plutôt que de se lancer seule sans expérience, Aude a choisi la sécurité et l'accompagnement d'une franchise : **Miss Cookies Coffee**. Après une formation au siège à Dijon, elle a ouvert sa boutique rue des Ponts. Le rythme est intense (7j/7 au début), mais elle se sent "enfin à sa place", rassurée par le réseau sur la gestion.

      ### Si vous voulez faire comme Aude
      Vous voulez entreprendre mais vous avez peur de la gestion ?
      * **Pensez à la franchise :** C'est un excellent moyen de se lancer avec un filet de sécurité (formation, marketing, concepts éprouvés).
      * **Acceptez le changement de rythme :** Passer du fonctionnariat au commerce demande une adaptation physique et mentale.
      * **Faites-vous accompagner :** Aude a eu une employée de la franchise avec elle pour le lancement.
    MARKDOWN
  },
  {
    title: "L'alliance gourmande d'une hôtelière et d'une pâtissière",
    chapo: "Emma et Rahel ont fusionné leurs rêves pour créer Madame Bergamote, un lieu hybride mêlant salon de thé et ateliers créatifs.",
    location: "3 Grande Rue, 54000 Nancy",
    latitude: 48.6948, longitude: 6.1818,
    happened_on: Date.new(2025, 7, 17),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1556910103-1c02745a30bf?q=80&w=1600&auto=format&fit=crop",
    body: <<~MARKDOWN
      ### Le Profil
      Elles sont amies depuis 15 ans. Emma (36 ans) était directrice adjointe d'hôtel et passionnée de création manuelle. Rahel (39 ans) travaillait dans l'administration avant de tout quitter pour passer un CAP Pâtisserie.

      ### Le Déclic
      Rahel rêvait d'ouvrir un salon de thé. Emma rêvait d'ouvrir un atelier créatif. Plutôt que de choisir, elles ont décidé de fusionner leurs envies. "Nous en avons rêvé, alors nous l'avons fait".

      ### L'Action
      Elles ont créé **Madame Bergamote** en Ville Vieille. C'est un lieu où l'on vient pour déguster les pâtisseries de Rahel, mais aussi pour participer à des ateliers DIY (couronnes de fleurs, bijoux...) gérés par Emma. Elles réinventent le commerce de proximité en y ajoutant de l'expérience et de l'apprentissage.

      ### Si vous voulez faire comme Elles
      Vous avez un associé ?
      * **La complémentarité est votre force :** Emma gère la créativité/gestion, Rahel gère la production culinaire.
      * **Testez votre concept :** Rahel a commencé par régaler ses proches et faire ses armes dans une maison renommée.
      * **Créez une communauté :** Leurs ateliers créatifs fidélisent une clientèle qui revient pour apprendre.
    MARKDOWN
  },
  {
    title: "Elle quitte 20 ans d'éducation pour ouvrir un concept-store éthique",
    chapo: "Laure a mûri son projet pendant 3 ans. Elle a créé Galapaga, une boutique qui mêle consommation responsable et bien-être.",
    location: "Boulevard de Baudricourt, 54600 Villers-lès-Nancy",
    latitude: 48.6732, longitude: 6.1518,
    happened_on: Date.new(2024, 5, 2),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1526481280695-3c687fd543c0?q=80&w=1600&auto=format&fit=crop",
    body: <<~MARKDOWN
      ### Le Profil
      Laure a consacré plus de vingt ans aux enfants. D'abord baby-sitter, puis animatrice BAFA, elle est devenue éducatrice de jeunes enfants. Une carrière riche de sens, mais à l'approche de la quarantaine, l'envie de créer son propre univers s'est faite sentir.

      ### Le Déclic
      C'est le confinement qui a tout déclenché. Ce temps suspendu lui a permis de réfléchir à ses valeurs : l'éthique, l'écologie, le local. Il lui a fallu trois ans de patience et de détermination pour passer de l'idée à la réalité, soutenue par la mairie pour trouver le local idéal.

      ### L'Action
      Elle a ouvert **Galapaga**, un lieu qui lui ressemble. Laure ne s'est pas contentée d'acheter des étagères : elle a fabriqué la plupart des meubles elle-même avec du bois de récupération ! Elle y propose des produits qu'elle a personnellement testés et approuvés (jouets en bois, cosmétiques rechargeables, cookies artisanaux), privilégiant toujours l'impact positif.

      ### Si vous voulez faire comme Laure
      Vous voulez ouvrir une boutique engagée ?
      * **Soyez patient :** Laure a mis 3 ans à concrétiser son projet. Ne précipitez pas la recherche du local.
      * **Mettez la main à la pâte :** Fabriquer son mobilier (upcycling) donne une âme unique au lieu et réduit les coûts.
      * **Curatez votre offre :** Ne vendez que ce que vous aimez et ce que vous avez testé. La sincérité est votre meilleur argument de vente.
    MARKDOWN
  },
  {
    title: "Prof d'anglais pendant 24 ans, elle devient pâtissière de marché",
    chapo: "Alexandra aimait enseigner, mais sa passion pour la pâtisserie a pris le dessus. Elle régale désormais le marché bio de Vandœuvre.",
    location: "Marché Bio, 54500 Vandœuvre-lès-Nancy",
    latitude: 48.6605, longitude: 6.1754,
    happened_on: Date.new(2024, 9, 1),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1579372786545-d24232daf58c?q=80&w=1600&auto=format&fit=crop",
    body: <<~MARKDOWN
      ### Le Profil
      Pendant près de 25 ans, Alexandra a enseigné l'anglais au lycée Stanislas. Une vocation née dès le collège. Elle aimait son métier, mais une autre passion, plus gourmande, commençait doucement à fermenter dans sa cuisine.

      ### Le Déclic
      Tout commence par un défi lancé par une amie en 2020 : passer le CAP pâtisserie en candidate libre. Cette formation agit comme une révélation. Elle se découvre capable de réaliser des techniques complexes. "La gourmandise est l'art d'utiliser la nourriture pour apporter du plaisir", réalise-t-elle.

      ### L'Action
      Alexandra n'a pas tout lâché brutalement. Elle a commencé par créer sa microentreprise, *Alex’s Pastries*, en parallèle de l'enseignement ("side project"). Face au succès de ses commandes pour des mariages et des baptêmes, elle a fini par quitter l'Éducation nationale pour se consacrer à 100 % à ses gâteaux sur le marché bio.

      ### Si vous voulez faire comme Alexandra
      Vous hésitez à quitter un emploi stable ?
      * **Testez en "Side Project" :** Alexandra a commencé sa microentreprise sans démissionner. C'est le meilleur moyen de valider son marché.
      * **La voie "Candidate Libre" :** On peut obtenir des diplômes techniques (CAP) sans retourner à l'école à temps plein. Renseignez-vous !
      * **Le soutien familial :** C'est une aventure collective. L'adhésion du conjoint et des enfants est un moteur essentiel.
    MARKDOWN
  },
  {
    title: "Du burn-out à la liberté : Fred a repris le volant de sa vie",
    chapo: "Après un burn-out, Frédéric a quitté son poste de manager pour devenir chauffeur de taxi. Il a perdu en salaire mais gagné une liberté inestimable.",
    location: "Saulxures-lès-Nancy (54420)",
    latitude: 48.6946, longitude: 6.2424,
    happened_on: Date.new(2025, 1, 15),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?q=80&w=1600&auto=format&fit=crop",
    body: <<~MARKDOWN
      ### Le Profil
      Pendant des années, Frédéric, 55 ans, était manager référent d'une équipe de 30 personnes. Une carrière stable en apparence, mais la pression de la "rentabilité à outrance" a fini par l'user.

      ### Le Déclic
      Le 8 avril 2021, c'est la rupture : le burn-out. Frédéric ne se reconnaît plus dans les valeurs de son entreprise. À 54 ans, il se retrouve face au vide, mais avec une certitude : il veut retrouver de l'humain et de l'autonomie.

      ### L'Action
      Il retourne à l'école pour deux mois de formation intensive (gestion, sécurité). Il investit dans une licence et une Tesla pour lancer *Fred Taxi*. Aujourd'hui, il fait du transport médical et scolaire. Il a troqué la pression des chiffres contre des sourires, savourant chaque jour "le bonheur d'être libre".

      ### Si vous voulez faire comme Fred
      Rebondir après 50 ans, c'est possible.
      * **Investissez sur vous :** Fred n'a pas hésité à se former et à investir financièrement (achat de la licence) pour assurer son avenir.
      * **Visez une niche :** Il s'est spécialisé (transport assis médicalisé, sièges autos pour enfants). C'est là que se trouve la valeur ajoutée.
      * **La liberté a un prix :** Il ne se verse pas encore de gros salaire au début, mais la satisfaction personnelle, elle, est immédiate.
    MARKDOWN
  },
  {
    title: "Elle quitte l'Ehpad pour offrir un \"Écrin\" à sa campagne",
    chapo: "Laura ne se retrouvait plus dans les conditions de travail à l'hôpital. Elle a ouvert le bar lounge qui manquait à Damelevières.",
    location: "Damelevières (54360)",
    latitude: 48.5583, longitude: 6.3869,
    happened_on: Date.new(2025, 9, 11),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?q=80&w=1600&auto=format&fit=crop",
    body: <<~MARKDOWN
      ### Le Profil
      Laura, 30 ans, a travaillé dix ans en Ehpad. Elle aimait ce métier humain, mais le manque de moyens et de temps pour les résidents l'a poussée à chercher du sens ailleurs.

      ### Le Déclic
      C'est en faisant des "extras" le soir dans des bars qu'elle a eu la révélation. Elle y a trouvé une ambiance conviviale qu'elle ne trouvait plus à l'hôpital. Elle a constaté qu'il manquait un lieu qualitatif dans sa commune rurale.

      ### L'Action
      Elle a créé **L'Écrin**. Pas un simple bistrot, mais un bar lounge "haut de gamme" ouvert à tous. Elle a voulu prouver qu'on n'est pas obligé d'habiter une grande métropole pour avoir accès à des lieux sympas. C'est un pari sur la redynamisation de son territoire.

      ### Si vous voulez faire comme Laura
      Vous voulez entreprendre en zone rurale ?
      * **Identifiez le manque :** Laura a vu qu'il n'y avait pas d'offre "Lounge" chez elle. Ne copiez pas l'existant, apportez ce qui manque.
      * **Testez le terrain :** Faire des "extras" avant de se lancer permet de voir si le métier nous plaît vraiment au quotidien.
      * **Soignez le cadre :** En campagne, le "bouche à oreille" va vite. Si le lieu est beau et l'accueil chaleureux, le succès suit.
    MARKDOWN
  },
  {
    title: "Elle fait voyager les Toulois avec ses saveurs exotiques",
    chapo: "Marielle ne trouvait pas les produits de son île à Toul. Elle a transformé ce manque en opportunité suite à un souci de santé.",
    location: "9 rue Pont-des-Cordeliers, 54200 Toul",
    latitude: 48.6756, longitude: 5.8906,
    happened_on: Date.new(2025, 5, 3),
    source_name: "L'Est Républicain",
    image_url: "https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?q=80&w=1600&auto=format&fit=crop",
    body: <<~MARKDOWN
      ### Le Profil
      Aide-soignante d'origine martiniquaise, Marielle vit à Toul depuis 15 ans. Suite à des problèmes de santé, elle a dû envisager une reconversion professionnelle totale.

      ### Le Déclic
      Depuis son arrivée, elle faisait le même constat : impossible de trouver des produits antillais locaux. Cette frustration, combinée à l'obligation de changer de métier, a été le catalyseur. "Si ça n'existe pas, je vais le créer".

      ### L'Action
      Elle a ouvert **Saveurs Exotics**. Elle y vend des ignames, des bananes plantains, et diffuse du zouk dans la boutique ! Plus qu'une épicerie, elle prévoit d'ouvrir un salon de thé pour en faire un lieu de vie. Elle a transformé une contrainte médicale en une aventure qui valorise sa culture.

      ### Si vous voulez faire comme Marielle
      Comment transformer un pépin en pépite ?
      * **Parting from a problem:** La meilleure idée de business est souvent de résoudre un problème que vous rencontrez vous-même (ici, l'absence de produits).
      * **Affirmez votre identité :** Marielle ne vend pas juste de la nourriture, elle vend "sa" Martinique. C'est ce qui rend son commerce unique.
      * **Voyez plus loin :** Elle commence par l'épicerie, mais projette déjà le salon de thé. Ayez toujours une vision de l'étape d'après.
    MARKDOWN
  }
]

stories_data.each do |data|
  # On utilise external_url comme clé d'unicité potentielle ou le titre
  Story.find_or_create_by!(title: data[:title]) do |s|
    s.assign_attributes(data)
    s.is_active = true # On active aussi les stories au cas où
  end
end
puts "✅ #{Story.count} belles histoires créées."


# ==============================================================================
# 2. LES OPPORTUNITÉS (OPPORTUNITIES)
# ==============================================================================
puts "🚀 Création des Opportunités (avec focus Écologiser)..."

opportunities_data = [
  # --- CATÉGORIE : ÉCOLOGISER (Focus demandé) ---
  {
    title: "Jetez ? Pas question ! Venez réparer au Repair Café",
    category: "ecologiser", # Important : minuscule pour le thème
    location: "MJC Villers-lès-Nancy (54600)",
    latitude: 48.6732, longitude: 6.1518,
    external_url: "https://repaircafe.org/",
    image_url: "https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=1600&auto=format&fit=crop",
    description: <<~MARKDOWN
      Votre grille-pain fait la grève ? Votre chaise préférée est bancale ? Ne les jetez pas !

      Le Repair Café de Villers est un atelier collaboratif où nous apprenons à réparer ensemble. L'objectif n'est pas de faire réparer votre objet par un technicien (ce n'est pas un SAV !), mais de mettre les mains dans le cambouis avec l'aide de nos bénévoles passionnés.

      ### Ce que vous allez y faire
      Vous apportez vos objets en panne (petit électroménager, vêtements, vélos, jouets...) et vous vous installez avec un réparateur bénévole. Ensemble, vous ouvrez, diagnostiquez et tentez de réparer. C'est l'occasion unique de comprendre comment fonctionnent vos objets.

      ### Pourquoi c'est génial ?
      C'est gratuit, écologique et convivial ! On lutte contre l'obsolescence programmée tout en buvant un café. Vous repartez avec la fierté d'avoir prolongé la vie de votre objet (et d'avoir économisé l'achat d'un neuf).

      ### Infos pratiques
      * **Quand ?** Le premier samedi du mois, de 14h à 17h.
      * **Où ?** À la MJC de Villers-lès-Nancy.
      * **Prix :** Entrée libre (une tirelire est dispo pour soutenir l'asso).

      *Attention : une seule réparation par personne pour que tout le monde puisse passer !*
    MARKDOWN
  },
  {
    title: "Atelier Fresque du Climat : comprenez tout en 3h",
    category: "ecologiser",
    location: "Octroi Nancy, 47 Bd d'Austrasie",
    latitude: 48.6955, longitude: 6.1983,
    external_url: "https://fresqueduclimat.org",
    image_url: "https://images.unsplash.com/photo-1542601906990-b4d3fb7d5fa5?q=80&w=1600&auto=format&fit=crop",
    description: <<~MARKDOWN
      Vous entendez parler du changement climatique tous les jours, mais avez-vous une vision d'ensemble ? La Fresque du Climat est un atelier ludique et collaboratif pour comprendre les causes et les conséquences du dérèglement.

      ### Comment ça se passe ?
      En équipe, vous devez relier 42 cartes entre elles pour reconstituer la fresque du système climatique. C'est visuel, intelligent et accessible à tous (pas besoin d'être un expert du GIEC !).

      ### L'impact
      En 3 heures, vous gagnez des années de compréhension. On sort de cet atelier motivé pour agir, sans culpabilité, mais avec lucidité.
    MARKDOWN
  },

  # --- CATÉGORIE : BÉNÉVOLAT ---
  {
    title: "Maraude solidaire : apportez de la chaleur humaine",
    category: "benevolat",
    location: "Place Maginot, 54000 Nancy",
    latitude: 48.6890, longitude: 6.1780,
    external_url: "https://www.croix-rouge.fr",
    image_url: "https://images.unsplash.com/photo-1469571486292-0ba58a3f068b?q=80&w=1600&auto=format&fit=crop",
    description: <<~MARKDOWN
      Rejoignez l'équipe des maraudeurs du vendredi soir. Pas besoin de compétences médicales, juste de l'écoute et de la bienveillance.

      ### Votre mission
      Aller à la rencontre des personnes sans-abri en centre-ville pour distribuer des boissons chaudes, des duvets, mais surtout pour discuter. Briser la solitude est aussi vital que de manger.

      ### Engagement
      Une soirée par mois minimum (20h - 23h). Formation "écoute active" assurée par l'asso avant la première maraude.
    MARKDOWN
  },

  # --- CATÉGORIE : ENTREPRENDRE ---
  {
    title: "Café des Entrepreneurs : Testez votre idée !",
    category: "entreprendre",
    location: "Pépinière d'entreprises, 54000 Nancy",
    latitude: 48.6833, longitude: 6.1667, # Approx
    external_url: "https://www.grandnancy.eu",
    image_url: "https://images.unsplash.com/photo-1519389950473-47ba0277781c?q=80&w=1600&auto=format&fit=crop",
    description: <<~MARKDOWN
      Vous avez une idée de projet mais vous n'osez pas vous lancer ? Venez la pitcher dans une ambiance bienveillante !

      ### Le concept
      5 minutes pour présenter votre idée devant d'autres porteurs de projet et des mentors. Pas de jugement, que du feedback constructif pour vous aider à avancer.

      ### Pour qui ?
      Tout le monde ! Que vous vouliez ouvrir une boulangerie ou lancer une start-up tech. L'important, c'est l'envie.
    MARKDOWN
  },

  # --- CATÉGORIE : FORMATION ---
  {
    title: "Initiation au Code : Créez votre premier site web",
    category: "formation",
    location: "Epitech Nancy, Rue des Jardiniers",
    latitude: 48.6960, longitude: 6.1950,
    external_url: "https://www.wagon.com",
    image_url: "https://images.unsplash.com/photo-1531482615713-2afd69097998?q=80&w=1600&auto=format&fit=crop",
    description: <<~MARKDOWN
      Le numérique vous fait peur ? Démystifiez-le le temps d'une journée d'initiation gratuite.

      ### Au programme
      Vous apprendrez les bases du HTML et du CSS. À la fin de la journée, vous aurez codé et mis en ligne votre propre page de présentation.

      ### Pourquoi participer ?
      Même si vous ne voulez pas devenir développeur, comprendre comment fonctionne le web est une compétence clé aujourd'hui, quel que soit votre métier.
    MARKDOWN
  },

  # --- CATÉGORIE : RENCONTRES ---
  {
    title: "Soirée Jeux de Société Intergénérationnelle",
    category: "rencontres",
    location: "Médiathèque Manufacture, Nancy",
    latitude: 48.6980, longitude: 6.1750,
    external_url: "https://mediatheques.nancy.fr",
    image_url: "https://images.unsplash.com/photo-1606167668584-78701c57f13d?q=80&w=1600&auto=format&fit=crop",
    description: <<~MARKDOWN
      Marre des écrans ? Venez jouer !

      ### Le principe
      On mélange les tables : étudiants, familles, retraités. On sort les classiques (Dixit, Aventuriers du Rail) et on découvre des nouveautés. Le jeu est le meilleur prétexte pour briser la glace.

      ### Ambiance
      Détendue et rigolote. Des animateurs sont là pour expliquer les règles, donc pas besoin de lire la notice pendant 20 minutes !
    MARKDOWN
  }
]

opportunities_data.each do |data|
  # On utilise external_url comme clé d'unicité potentielle ou le titre
  Opportunity.find_or_create_by!(title: data[:title]) do |o|
    o.assign_attributes(data)
    o.is_active = true # <=== LA LIGNE MAGIQUE QUI ACTIVE L'OPPORTUNITÉ
  end
end

puts "✅ #{Opportunity.count} opportunités créées."
puts "🎉 Seed terminé avec succès ! Votre app est prête."
