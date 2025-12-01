# db/seeds.rb — Données de départ pour Déclic
# =====================================================
#
# PHILOSOPHIE :
# - Ce fichier contient UNIQUEMENT des opportunités RÉELLES et vérifiées
# - Coordonnées GPS fixes et précises (pas de randomisation)
# - Textes engageants qui donnent vraiment envie de participer
# - Idempotent : peut être exécuté plusieurs fois sans créer de doublons
#
# SOURCE DE VÉRITÉ :
# Pour ajouter/modifier des opportunités en production, préférez :
# - L'interface admin (/admin/opportunities)
# - L'import CSV depuis opps_corridor_active.csv
# =====================================================

# =================== Helpers simplifiés ===================
Opportunity.destroy_all
Story.destroy_all

# db/seeds.rb — Données de départ pour Déclic
# =====================================================
#
# PHILOSOPHIE :
# - Ce fichier contient UNIQUEMENT des opportunités RÉELLES et vérifiées
# - Coordonnées GPS fixes et précises (pas de randomisation)
# - Textes engageants qui donnent vraiment envie de participer
# - Idempotent : peut être exécuté plusieurs fois sans créer de doublons
#
# SOURCE DE VÉRITÉ :
# Pour ajouter/modifier des opportunités en production, préférez :
# - L'interface admin (/admin/opportunities)
# - L'import CSV depuis opps_corridor_active.csv
# =====================================================

# =================== Helpers simplifiés ===================

CAT_IMAGES = {
  "benevolat"    => "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1200&auto=format&fit=crop",
  "formation"    => "https://images.unsplash.com/photo-1513258496099-48168024aec0?q=80&w=1200&auto=format&fit=crop",
  "rencontres"   => "https://images.unsplash.com/photo-1558222217-0d77a6d3b3d1?q=80&w=1200&auto=format&fit=crop",
  "entreprendre" => "https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=1200&auto=format&fit=crop",
  "ecologiser"   => "https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=1200&auto=format&fit=crop",
  "default"      => "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1200&auto=format&fit=crop"
}.freeze


def image_for(category)
  CAT_IMAGES[category.to_s] || CAT_IMAGES["default"]
end

def build_description(category:, base_desc:, link: nil, when_line:)
  parts = []
  parts << "![Illustration](#{image_for(category)})"
  parts << ""
  parts << "### Pourquoi franchir le pas ?"
  parts << base_desc.strip
  parts << ""
  parts << "🗓️ **Quand ?** #{when_line}"
  parts << ""
  parts << "### Ce que tu vas gagner"
  parts << "• Des **compétences immédiatement utiles** que tu pourras appliquer dès le lendemain"
  parts << "• Un **réseau bienveillant** de personnes qui partagent tes ambitions"
  parts << "• La **confiance** de te lancer — parce que tu ne seras plus seul·e"
  parts << ""
  parts << "Pas besoin d'être expert·e. On est tous·tes là pour apprendre ensemble. 🙌"
  parts << ""
  parts << "🔗 **En savoir plus** : #{link}" if link.present?
  parts.join("\n")
end

# =================== Opportunités Nancy (réelles & vérifiées) ===================

nancy_opportunities = [
  # ===== ENTREPRENDRE =====
  {
    title: "Atelier — Construire son Business Plan",
    description: build_description(
      category: "entreprendre",
      base_desc: "🎯 **Tu as une idée ? Transforme-la en plan d'action béton.**\n\nCet atelier de la CCI te donne la méthode complète : trame financière claire, hypothèses réalistes, et les mots justes pour convaincre investisseurs et partenaires.\n\nTu repars avec **ton business plan structuré** et la confiance de le pitcher devant n'importe qui. Les formateurs sont des entrepreneurs qui sont passés par là — leurs conseils valent de l'or.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Jeudi 13 novembre 2025, 14:00–17:00"
    ),
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Jeudi 13/11/2025, 14:00–17:00",
    latitude: 48.6932,
    longitude: 6.1829,
    is_active: true,
    tags: "business plan,financement,atelier",
    image_url: image_for("entreprendre")
  },
  {
    title: "Permanence création d'entreprise (sur RDV)",
    description: build_description(
      category: "entreprendre",
      base_desc: "🚀 **Envie de te lancer, mais tu ne sais pas par où commencer ?**\n\nRéserve un créneau avec un conseiller de la CCI pour un entretien 100% personnalisé. Statut juridique, aides financières, étapes concrètes — tu repars avec une feuille de route claire et les contacts des bons partenaires (BPI, CMA, réseaux locaux).\n\nC'est **gratuit, sans engagement**, et ça peut te faire gagner des mois de galère administrative.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Chaque mardi (dès nov. 2025), 09:30–12:00 — sur rendez-vous"
    ),
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Hebdomadaire — sur rendez-vous",
    latitude: 48.6932,
    longitude: 6.1829,
    is_active: true,
    tags: "diagnostic,statuts,accompagnement",
    image_url: image_for("entreprendre")
  },
  {
    title: "Afterwork Entrepreneurs Nancy",
    description: build_description(
      category: "entreprendre",
      base_desc: "🍻 **Le réseau qui fait vraiment avancer les projets.**\n\nChaque mois, porteurs de projets, mentors et experts locaux se retrouvent pour partager leurs galères et leurs victoires. Pitch ton idée en 2 minutes, reçois des retours concrets, et repars avec de nouveaux contacts qui peuvent tout changer.\n\nL'ambiance est cool, les échanges sont vrais, et **certaines collaborations nées ici sont devenues des boîtes qui tournent**.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Jeudi 27 novembre 2025, 18:30–20:30"
    ),
    category: "entreprendre",
    organization: "Réseau local (CCI & partenaires)",
    location: "Centre-ville, 54000 Nancy",
    time_commitment: "Mensuel, 18:30–20:30",
    latitude: 48.6918,
    longitude: 6.1837,
    is_active: true,
    tags: "réseau,pitch,mentorat",
    image_url: image_for("entreprendre")
  },
  {
    title: "Atelier — Financer son projet",
    description: build_description(
      category: "entreprendre",
      base_desc: "💰 **Ton idée est là. L'argent aussi — il faut juste savoir où chercher.**\n\nCet atelier décortique TOUS les financements possibles : prêts d'honneur, subventions régionales, love money, dispositifs BPI… Tu apprendras à monter un dossier en béton et à présenter ton prévisionnel comme un·e pro.\n\n**Résultat concret** : tu repars avec une stratégie de financement adaptée à TON projet.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Vendredi 28 novembre 2025, 09:30–12:00"
    ),
    category: "entreprendre",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Vendredi 28/11/2025, 09:30–12:00",
    latitude: 48.6932,
    longitude: 6.1829,
    is_active: true,
    tags: "financement,bpi,subventions",
    image_url: image_for("entreprendre")
  },
  {
    title: "Mentorat entrepreneur·e — rendez-vous découverte",
    description: build_description(
      category: "entreprendre",
      base_desc: "🧭 **Besoin d'un regard extérieur pour voir plus clair ?**\n\nCe programme te met en relation avec des mentors expérimentés (stratégie, juridique, produit) qui ont réussi et qui veulent t'aider. En quelques sessions, tu vas **clarifier ta feuille de route 90 jours** et éviter les erreurs de débutant.\n\nTu n'es plus seul·e face aux décisions difficiles. Le mentorat, c'est l'accélérateur dont tu as besoin.",
      link: "https://communs-entrepreneurs.fr",
      when_line: "Entretiens continus — créneaux nov.–déc. 2025"
    ),
    category: "entreprendre",
    organization: "Communs d'entrepreneurs Nancy",
    location: "Nancy & Métropole",
    time_commitment: "Sur candidature",
    latitude: 48.692,
    longitude: 6.184,
    is_active: true,
    tags: "mentorat,roadmap,coaching",
    image_url: image_for("entreprendre")
  },

  # ===== FORMATION =====
  {
    title: "Atelier Pitch & Storytelling",
    description: build_description(
      category: "formation",
      base_desc: "🎤 **Ton projet est génial. Maintenant, apprends à le raconter.**\n\nEn 3 heures, tu vas structurer un pitch qui capte l'attention, qui reste en tête, et qui donne envie d'en savoir plus. Problème, solution, traction — la méthode est simple et redoutablement efficace.\n\nOn filme, on décortique, on ajuste. Tu repars avec **un pitch rodé** et la confiance de le délivrer devant n'importe qui.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Mercredi 19 novembre 2025, 14:00–17:00"
    ),
    category: "formation",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Mercredi 19/11/2025, 14:00–17:00",
    latitude: 48.6932,
    longitude: 6.1829,
    is_active: true,
    tags: "pitch,communication,atelier",
    image_url: image_for("formation")
  },
  {
    title: "Matinale Numérique — TPE/PME",
    description: build_description(
      category: "formation",
      base_desc: "💻 **Développe ta présence en ligne sans exploser ton budget.**\n\nRéférencement local, réseaux sociaux qui convertissent, outils no-code pour créer vite et bien — cette matinale condense l'essentiel en 90 minutes avec des **exemples concrets d'entreprises du coin** qui cartonnent.\n\nParfait pour le petit déj + boost de motivation avant d'attaquer ta journée !",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Mardi 18 novembre 2025, 08:30–10:00"
    ),
    category: "formation",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Mensuel, 08:30–10:00",
    latitude: 48.6932,
    longitude: 6.1829,
    is_active: true,
    tags: "numérique,seo,no-code",
    image_url: image_for("formation")
  },
  {
    title: "Découvrir la méthodologie HACCP (restauration)",
    description: build_description(
      category: "formation",
      base_desc: "🍴 **Tu rêves d'ouvrir un resto, un food truck, un café ? Commence par ici.**\n\nLa formation HACCP, c'est **obligatoire** avant d'ouvrir, mais c'est aussi hyper utile : tu apprendras les bases de l'hygiène alimentaire, les points critiques, et comment éviter les galères sanitaires.\n\nFormat court, pratique, et tu repars avec ta certification en poche.",
      link: "https://www.nancy.cci.fr/evenements",
      when_line: "Sessions bimensuelles — prochains créneaux nov.–déc. 2025"
    ),
    category: "formation",
    organization: "CCI Grand Nancy",
    location: "53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Session bimensuelle",
    latitude: 48.6932,
    longitude: 6.1829,
    is_active: true,
    tags: "haccp,restauration,hygiène",
    image_url: image_for("formation")
  },
  {
    title: "Executive MBA — se réinventer (ICN Business School)",
    description: build_description(
      category: "formation",
      base_desc: "🎓 **Cadre ou dirigeant·e, tu sens qu'il est temps de passer à autre chose ?**\n\nL'Executive MBA d'ICN, c'est le parcours pour celles et ceux qui veulent **se transformer** : leadership, stratégie, innovation. Tu travailles sur un vrai projet de transformation pendant 18-24 mois, compatible avec ton activité pro.\n\nÀ la clé : un diplôme reconnu, un réseau solide, et une nouvelle trajectoire professionnelle.",
      link: "https://www.lasemaine.fr/enseignement-formation/executive-mba-quand-icn-aide-les-cadres-a-se-reinventer/",
      when_line: "Rentrée de printemps 2026 — candidatures ouvertes dès nov. 2025"
    ),
    category: "formation",
    organization: "ICN Business School",
    location: "86 Rue Sergent Blandan, 54000 Nancy",
    time_commitment: "Part-time (18–24 mois)",
    latitude: 48.6829,
    longitude: 6.1766,
    is_active: true,
    tags: "executive,mba,leadership,transformation",
    image_url: image_for("formation")
  },

  # ===== RENCONTRES =====
  {
    title: "Café-projets — échanges entre pairs",
    description: build_description(
      category: "rencontres",
      base_desc: "☕ **Galère sur ton projet ? Viens en parler autour d'un café.**\n\nCe rendez-vous bimensuel, c'est le moment où tu partages tes avancées, tes blocages, tes ressources. Pas de jugement, que de l'entraide. Format court (1h30), bienveillant, et **étonnamment efficace** pour débloquer des situations.\n\nOuvert à tous·tes, débutant·es compris. Parfois, il suffit d'un regard extérieur pour voir la solution.",
      link: "https://www.grandnancy.eu",
      when_line: "Tous les 15 jours, jeudi 18:30 — prochain : 06 novembre 2025"
    ),
    category: "rencontres",
    organization: "Communauté Déclic Nancy",
    location: "Place Stanislas, 54000 Nancy",
    time_commitment: "Tous les 15 jours, 18:30",
    latitude: 48.6937,
    longitude: 6.1834,
    is_active: true,
    tags: "pair-à-pair,entraide,réseau",
    image_url: image_for("rencontres")
  },
  {
    title: "Visite — Tiers-lieu & fablab",
    description: build_description(
      category: "rencontres",
      base_desc: "🛠️ **Découvre un lieu où les idées prennent forme.**\n\nVisite guidée du fablab : imprimantes 3D, découpe laser, outils de prototypage… Tu vas rencontrer des makers passionnés qui partagent leurs astuces, et tu découvriras les ateliers à venir.\n\n**Parfait si tu veux** passer du concept au prototype, ou juste traîner avec des gens créatifs qui font des trucs concrets.",
      link: "https://lafabriquedespossibles.fr",
      when_line: "Samedi 22 novembre 2025, 10:00–12:00"
    ),
    category: "rencontres",
    organization: "La Fabrique des Possibles",
    location: "Nancy",
    time_commitment: "Mensuel",
    latitude: 48.682,
    longitude: 6.186,
    is_active: true,
    tags: "tiers-lieu,fablab,prototype",
    image_url: image_for("rencontres")
  },

  # ===== BÉNÉVOLAT =====
  {
    title: "Repair Café — accueil & logistique",
    description: build_description(
      category: "benevolat",
      base_desc: "🔧 **Donne un coup de main pour réparer au lieu de jeter.**\n\nPas besoin d'être bricoleur·se — on cherche des gens pour accueillir le public, orienter vers les bon·nes réparateur·ices, et donner un coup de main logistique. L'ambiance est conviviale, la cause est utile (anti-gaspi !), et **tu vas croiser des profils inspirants**.\n\nUn samedi matin par mois, et tu fais une vraie différence.",
      link: "https://mjc-bazin.fr",
      when_line: "Samedi 15 novembre 2025, 09:30–12:30"
    ),
    category: "benevolat",
    organization: "MJC Bazin",
    location: "47 Rue Henri Bazin, 54000 Nancy",
    time_commitment: "Mensuel, samedi matin",
    latitude: 48.6848,
    longitude: 6.1899,
    is_active: true,
    tags: "réparation,accueil,convivial",
    image_url: image_for("benevolat")
  },
  {
    title: "Atelier couture — coup de main",
    description: build_description(
      category: "benevolat",
      base_desc: "🪡 **Aide les débutant·es à se lancer dans la couture.**\n\nTu n'as pas besoin d'être styliste — juste d'être patient·e et souriant·e. Prendre les mesures, préparer le matériel, accompagner celles et ceux qui débutent… **Ton rôle, c'est de rendre l'atelier accueillant** pour que tout le monde ose essayer.\n\nChaque mercredi soir, ambiance bonne humeur garantie.",
      link: "https://mjc-bazin.fr",
      when_line: "Chaque mercredi 17:30–19:30 (nov.–déc. 2025)"
    ),
    category: "benevolat",
    organization: "MJC Bazin",
    location: "47 Rue Henri Bazin, 54000 Nancy",
    time_commitment: "Hebdomadaire",
    latitude: 48.6848,
    longitude: 6.1899,
    is_active: true,
    tags: "couture,atelier,pédagogie",
    image_url: image_for("benevolat")
  },
  {
    title: "Distribution alimentaire",
    description: build_description(
      category: "benevolat",
      base_desc: "❤️ **2–3 heures par semaine qui changent vraiment la vie des gens.**\n\nAux Restos du Cœur, on a besoin de bras pour la distribution, l'accueil, le réassort. L'équipe est soudée, l'ambiance est respectueuse, et **chaque geste compte**.\n\nTu découvriras une solidarité concrète, loin des grands discours. Viens tester un créneau — tu verras si ça te parle.",
      link: "https://www.restosducoeur.org/devenir-benevole/",
      when_line: "Créneaux hebdomadaires (2–3 h), dès novembre 2025"
    ),
    category: "benevolat",
    organization: "Restos du Cœur — Nancy",
    location: "Centre-ville, 54000 Nancy",
    time_commitment: "Hebdomadaire (créneaux 2–3 h)",
    latitude: 48.689,
    longitude: 6.184,
    is_active: true,
    tags: "solidarité,logistique,accueil",
    image_url: image_for("benevolat")
  },
  {
    title: "Tri de dons & mise en rayon",
    description: build_description(
      category: "benevolat",
      base_desc: "📦 **Transforme des dons en ressources pour ceux qui en ont besoin.**\n\nAu Secours Populaire, tu participeras au tri, à l'étiquetage, et à la mise en rayon dans la boutique solidaire. C'est concret, c'est utile, et **tu vois direct l'impact de ton action**.\n\nQuelques heures par semaine, et tu fais partie d'un circuit vertueux qui redonne une seconde vie aux objets.",
      link: "https://www.secourspopulaire.fr",
      when_line: "2–4 h / semaine — créneaux nov.–déc. 2025"
    ),
    category: "benevolat",
    organization: "Secours Populaire — Nancy",
    location: "Nancy",
    time_commitment: "2–4 h / semaine",
    latitude: 48.69,
    longitude: 6.18,
    is_active: true,
    tags: "tri,solidarité,boutique",
    image_url: image_for("benevolat")
  },
  {
    title: "Bénévolat boutique & recyclerie",
    description: build_description(
      category: "benevolat",
      base_desc: "♻️ **Fais vivre une économie circulaire qui a du sens.**\n\nÀ Emmaüs, tu accueilleras les clients, tu tiendras la caisse, tu trieras et réassortiras les rayons. Chaque objet vendu finance l'insertion de personnes en difficulté — **ton engagement a un double impact** : écologique et social.\n\nPonctuel ou régulier, viens comme tu peux. Ici, tout le monde est le bienvenu.",
      link: "https://emmaus-france.org",
      when_line: "Créneaux ponctuels et réguliers — dès novembre 2025"
    ),
    category: "benevolat",
    organization: "Emmaüs — Agglo de Nancy",
    location: "Heillecourt / agglomération nancéienne",
    time_commitment: "Ponctuel ou régulier",
    latitude: 48.654,
    longitude: 6.183,
    is_active: true,
    tags: "recyclerie,réemploi,accueil",
    image_url: image_for("benevolat")
  },
  {
    title: "Maraude & lien social",
    description: build_description(
      category: "benevolat",
      base_desc: "🌙 **Va à la rencontre de ceux qu'on ne voit plus.**\n\nEn binôme, tu partiras en maraude pour distribuer boissons chaudes, repas, et surtout : **écouter, orienter, redonner un peu de dignité**. C'est bouleversant, c'est humain, c'est une expérience qui te change.\n\nQuelques soirées par mois, et tu découvres une solidarité vraie, loin des clichés.",
      link: "https://www.francebenevolat.org",
      when_line: "Soirées (2–3 h) — tournées nov.–déc. 2025"
    ),
    category: "benevolat",
    organization: "Réseau local (associatif)",
    location: "Nancy — différents quartiers",
    time_commitment: "Soirées (2–3 h)",
    latitude: 48.692,
    longitude: 6.184,
    is_active: true,
    tags: "maraude,écoute,orientation",
    image_url: image_for("benevolat")
  }
]

# ===== LIEUX & STRUCTURES ENGAGÉES / BELLES HISTOIRES =====
nancy_opportunities += [
  {
    title: "Grande épicerie générale Nancy",
    description: build_description(
      category: "entreprendre",
      base_desc: <<~MD,
        La Grande Épicerie Générale, c’est un supermarché participatif où les coopératrices et coopérateurs décident ensemble de ce qu’on met dans les rayons.

        Pour faire ses courses, il faut :
        • participer **3 heures toutes les 4 semaines** aux tâches du magasin
        • prendre au moins **une part sociale** : tu deviens copropriétaire de la coopérative 🧑‍🤝‍🧑

        Ici, on privilégie :
        • des produits **locaux, bio, éthiques** chaque fois que possible
        • une **marge unique et transparente** (25 % sur tous les produits)
        • une gouvernance démocratique : **une personne = une voix**, pas de logique purement financière

        Tu peux t’y investir progressivement : d’abord comme coopérateur·rice qui assure ses créneaux, puis en rejoignant un **groupe de travail** pour faire grandir le projet (achats, communication, animation…). C’est un lieu de consommation, mais aussi un espace de lien social et d’apprentissage de la coopération.
      MD
      link: "https://www.grandeepiceriegenerale.fr",
      when_line: "Engagement régulier — 3 h toutes les 4 semaines"
    ),
    category: "entreprendre",
    organization: "Grande Épicerie Générale",
    location: "88 avenue du XXème Corps, 54000 Nancy",
    time_commitment: "3 h toutes les 4 semaines + implication possible en groupes de travail",
    is_active: true,
    tags: "coopérative,alimentation,supermarché participatif",
    image_url: image_for("entreprendre"),
    website: "https://www.grandeepiceriegenerale.fr",
    contact_email: "contact@grandeepiceriegenerale.fr"
  },
  {
    title: "Garage Solidaire de Lorraine",
    description: build_description(
      category: "benevolat",
      base_desc: <<~MD,
        Le Garage Solidaire de Lorraine, c’est **bien plus qu’un garage** : c’est un chantier d’insertion qui aide des personnes éloignées de l’emploi à retrouver un projet professionnel et une place dans la société.

        Sur place :
        • des salarié·es en insertion, accompagnés pendant **jusqu’à 2 ans**
        • un encadrement par une équipe pluridisciplinaire
        • un vrai parcours d’accompagnement social et professionnel

        Côté services, le Garage Solidaire :
        • répare et entretient des véhicules à **prix accessibles**
        • vend ou loue des voitures à des publics pour qui la mobilité est un frein à l’emploi
        • permet à chacun, quels que soient ses revenus, de contribuer à une mobilité **plus solidaire et plus écologique**.

        S’engager avec le Garage Solidaire, c’est soutenir à la fois l’insertion, la mobilité et l’économie circulaire.
      MD
      link: "https://garagesolidairelorraine.fr",
      when_line: "Accompagnement et services toute l’année — parcours d’insertion sur 24 mois"
    ),
    category: "benevolat",
    organization: "Garage Solidaire de Lorraine",
    location: "33 avenue de la Meurthe, 54320 Maxéville",
    time_commitment: "Engagement régulier possible (bénévolat, partenariats, accompagnement)",
    is_active: true,
    tags: "mobilité,insertion,solidarité,économie circulaire",
    image_url: image_for("benevolat"),
    website: "https://garagesolidairelorraine.fr",
    contact_email: "accueil@garagesolidairelorraine.fr"
  },
  {
    title: "Tricot Couture Service (TCS)",
    description: build_description(
      category: "benevolat",
      base_desc: <<~MD,
        Tricot Couture Service (TCS), c’est une association d’économie sociale et solidaire qui utilise la couture, le tricot, la broderie et le patchwork comme **support d’insertion et de lien social**.

        Sur ses chantiers d’insertion, TCS :
        • propose des **emplois et un cadre de travail** à des personnes éloignées de l’emploi
        • accompagne les salarié·es sur leurs projets de vie et de formation
        • crée des articles textiles sur commande pour des collectivités ou des structures locales

        TCS, c’est aussi :
        • un **laboratoire de cohésion sociale**
        • un fonds d’innovation sociale pour financer des projets à impact
        • des ateliers où se croisent habitants de tous âges autour des activités créatives

        En donnant du temps, des compétences ou en travaillant avec TCS, tu contribues à une **inclusion très concrète** et à une économie circulaire locale.
      MD
      link: "https://www.tricotcoutureservice.org/",
      when_line: "Ateliers et chantiers d’insertion en continu — toute l’année"
    ),
    category: "benevolat",
    organization: "Tricot Couture Service",
    location: "17 Rue de Bavière, 54500 Vandœuvre-lès-Nancy",
    time_commitment: "Engagement régulier ou ponctuel selon les ateliers et projets",
    is_active: true,
    tags: "insertion,couture,économie sociale,cohésion sociale",
    image_url: image_for("benevolat"),
    website: "https://www.tricotcoutureservice.org/",
    contact_email: "tricot_couture_services@orange.fr"
  },
  {
    title: "Le Relais — Friperie Ding Fring Laxou",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Le Relais collecte des tonnes de textiles usagés via un réseau de bornes, puis les trie dans son centre proche de Nancy. Les vêtements en bon état alimentent les boutiques Ding Fring, comme celle de Laxou ; les autres sont **recyclés** (isolant Métisse, chiffons, combustible…).

        Dans la boutique de Laxou, tu trouves :
        • des vêtements seconde main en très bon état, parfois neufs
        • des pièces vintage, des marques recherchées, des accessoires
        • des prix accessibles pour étudiants, familles, amateurs de fripes

        Acheter au Relais, c’est :
        • réduire drastiquement les déchets textiles
        • financer des **emplois en insertion**
        • soutenir une coopérative où les salarié·es peuvent devenir sociétaires

        C’est une **opportunité concrète d’écologiser ses achats**, tout en soutenant un modèle d’économie circulaire et solidaire.
      MD
      link: "https://www.lerelais.org",
      when_line: "Boutique ouverte toute l’année — horaires variables selon le magasin"
    ),
    category: "ecologiser",
    organization: "Le Relais / Ding Fring Laxou",
    location: "6 Rue de la Mortagne, 54520 Laxou",
    time_commitment: "Courses solidaires et engagées à ta convenance",
    is_active: true,
    tags: "seconde main,textile,réemploi,insertion,friperie",
    image_url: image_for("ecologiser"),
    website: "https://www.lerelais.org"
  },
  {
    title: "Le Noël vert du Grand Nancy",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Le Noël vert du Grand Nancy, c’est un marché de Noël **écoresponsable** qui rassemble une soixantaine de créateurs, artisans et producteurs locaux.

        Sur place :
        • des idées cadeaux durables : artisanat, produits locaux, objets réemployés
        • des animations pour découvrir d’autres façons de consommer
        • une ambiance festive, mais avec une vraie attention à l’empreinte écologique

        C’est l’endroit idéal pour préparer les fêtes en accord avec tes valeurs : soutenir l’économie locale, réduire les déchets et faire découvrir des alternatives à ton entourage.
      MD
      link: nil,
      when_line: "29–30 novembre 2025, 10h–18h (Salle Gentilly, Nancy)"
    ),
    category: "ecologiser",
    organization: "Métropole du Grand Nancy",
    location: "Salle Gentilly, 11 avenue du Rhin, 54000 Nancy",
    time_commitment: "Événement sur 2 jours — 29 et 30 novembre 2025, 10h–18h",
    starts_at: Time.zone.parse("2025-11-29 10:00"),
    ends_at:   Time.zone.parse("2025-11-30 18:00"),
    is_active: true,
    tags: "noël,écoresponsable,artisanat local,économie circulaire",
    image_url: image_for("ecologiser")
  },
  {
    title: "Le Fourgon — Courses consignées à domicile",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Le Fourgon remet la **consigne** au goût du jour : tu fais tes courses en ligne, tout arrive en contenants en verre réutilisables, livrés en véhicule électrique… et les contenants repartent lors de la tournée suivante.

        Concrètement :
        • plus de 700 références (boissons, épicerie, hygiène, entretien…)
        • des produits majoritairement locaux quand c’est possible
        • des bouteilles et bocaux en verre **réemployés jusqu’à 40 fois**

        Les impacts :
        • jusqu’à **79 % de CO₂ en moins** par rapport au tout-jetable
        • réduction massive des déchets d’emballages
        • tournées optimisées en véhicule électrique

        Tu commandes, tu remplis une caisse, tu te fais livrer à Pulnoy et dans un large rayon autour de Nancy. C’est un excellent moyen d’écologiser ton quotidien sans ajouter une charge mentale énorme.
      MD
      link: "https://www.lefourgon.com/fr",
      when_line: "Livraison régulière à domicile — selon tes commandes"
    ),
    category: "ecologiser",
    organization: "Le Fourgon",
    location: "10 Allée des Noires Terres, 54425 Pulnoy",
    time_commitment: "Courses consignées à la demande",
    is_active: true,
    tags: "consigne,zéro déchet,livraison,verre réemployable",
    image_url: image_for("ecologiser"),
    website: "https://www.lefourgon.com/fr"
  },
  {
    title: "Don de sang — Maison du Don Nancy",
    description: build_description(
      category: "benevolat",
      base_desc: <<~MD,
        La Maison du Don de Nancy accueille les donneurs de sang, de plasma et de plaquettes. **Aucun produit artificiel** ne peut remplacer ces dons : ils sont indispensables au quotidien pour soigner de nombreux patients.

        Sur place :
        • un parcours simple : inscription, entretien médical, prélèvement, collation
        • une équipe qui t’accompagne et répond à toutes tes questions
        • un accueil du lundi au vendredi, et même le samedi

        Il suffit :
        • d’être en bonne santé
        • d’avoir plus de 18 ans
        • de venir avec une pièce d’identité

        La durée de vie des produits sanguins est courte : la **régularité des dons** est essentielle. Ton don peut littéralement sauver des vies.
      MD
      link: "https://dondesang.efs.sante.fr/grand-est/maison-du-don-de-nancy",
      when_line: "Du lundi au vendredi 8h–19h, samedi 8h–16h"
    ),
    category: "benevolat",
    organization: "Établissement Français du Sang — Maison du Don de Nancy",
    location: "85–87 Boulevard Lobau, 54000 Nancy",
    time_commitment: "Don ponctuel (45–60 min) — possibilité de dons réguliers",
    is_active: true,
    tags: "santé,don de sang,solidarité",
    image_url: image_for("benevolat"),
    website: "https://dondesang.efs.sante.fr/grand-est/maison-du-don-de-nancy",
    contact_phone: "0 800 10 99 00"
  },
  {
    title: "Réunion « Prêt à vous lancer ? » — CCI",
    description: build_description(
      category: "entreprendre",
      base_desc: <<~MD,
        Tu as une idée de création d’entreprise mais tu ne sais pas par où commencer ? La CCI Meurthe-et-Moselle anime une réunion d’information « Prêt à vous lancer ? » pour t’aider à clarifier les étapes.

        Au programme :
        • les grandes étapes pour transformer ton idée en projet rentable
        • les différentes formes juridiques possibles
        • les aides et dispositifs existants
        • le processus concret d’immatriculation

        On parle aussi des **facteurs-clés de réussite** et de ce que signifie réellement « devenir chef d’entreprise ». C’est une excellente porte d’entrée pour passer de l’intention à l’action.
      MD
      link: "https://www.nancy.cci.fr/evenement/reunion-dinformation-pret-vous-lancer-0",
      when_line: "Mardi 9 décembre 2025, 9h30"
    ),
    category: "entreprendre",
    organization: "CCI Meurthe-et-Moselle",
    location: "51–53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Réunion d’information — 1/2 journée",
    starts_at: Time.zone.parse("2025-12-09 09:30"),
    ends_at:   Time.zone.parse("2025-12-09 12:00"),
    is_active: true,
    tags: "création d’entreprise,information,CCI",
    image_url: image_for("entreprendre"),
    website: "https://www.nancy.cci.fr/evenement/reunion-dinformation-pret-vous-lancer-0",
    contact_email: "creation@nancy.cci.fr"
  },
  {
    title: "Jimily — La box anniversaire qui aide les parents",
    description: build_description(
      category: "entreprendre",
      base_desc: <<~MD,
        Jimily, c’est une box anniversaire clé en main imaginée par Charline Didrat pour **simplifier la vie des parents** qui organisent un anniversaire à la maison.

        Le concept :
        • tu choisis une thématique (pirates, dinosaures, magie, licorne, safari, etc.)
        • tu sélectionnes l’âge (4–7 ans ou 7–11 ans) et le nombre d’invité·es
        • tu reçois une box avec décorations, vaisselle, activités, cadeaux invités et un guide pour animer la fête

        Les plus :
        • production locale ou française : boîtes et imprimés fabriqués à Nancy, articles sourcés en Alsace
        • supports réutilisables (à colorier, à garder)
        • une entrepreneure locale lauréate du concours « 101 femmes entrepreneures »

        C’est une belle histoire d’entrepreneuriat local, avec un projet qui allie **praticité pour les parents** et **ancrage territorial**.
      MD
      link: "https://jimily.fr/",
      when_line: "Box disponibles toute l’année — commande en ligne"
    ),
    category: "entreprendre",
    organization: "Jimily",
    location: "7 Rue Louis Pasteur, 54770 Dommartin-sous-Amance",
    time_commitment: "Commande en ligne — Livraison en quelques jours",
    is_active: true,
    tags: "belle histoire,entrepreneuriat,famille,anniversaire",
    image_url: image_for("entreprendre"),
    website: "https://jimily.fr/"
  },
  {
    title: "Soirée métiers dans la cité — APEC",
    description: build_description(
      category: "formation",
      base_desc: <<~MD,
        L’APEC organise une soirée « découverte métiers » pour cadres et jeunes diplômés qui envisagent une **reconversion ou un changement de trajectoire**.

        Le principe :
        • une trentaine « d’ambassadeurs métiers » sur place
        • des échanges libres pour découvrir des secteurs : formation, immobilier, commerce, environnement, etc.
        • un temps dédié pour poser toutes tes questions à celles et ceux qui font déjà ces métiers

        L’idée : passer de l’intention (« j’aimerais peut-être changer ») à une vision plus concrète des options possibles, en s’appuyant sur l’expertise de l’APEC pour lever les blocages.

        C’est un excellent point d’entrée si tu envisages une reconversion mais que tu te sens un peu perdu·e sur la suite.
      MD
      link: "https://www.apec.fr",
      when_line: "Mercredi 10 décembre 2025, en soirée (CCI Nancy)"
    ),
    category: "formation",
    organization: "APEC / CCI Meurthe-et-Moselle",
    location: "51–53 Rue Stanislas, 54000 Nancy",
    time_commitment: "Soirée unique — environ 3 heures",
    starts_at: Time.zone.parse("2025-12-10 18:00"),
    ends_at:   Time.zone.parse("2025-12-10 21:00"),
    is_active: true,
    tags: "reconversion,métiers,orientation,apec",
    image_url: image_for("formation"),
    website: "https://www.apec.fr"
  },
  {
    title: "MJC Lillebonne — Une fourmilière d’activités",
    description: build_description(
      category: "rencontres",
      base_desc: <<~MD,
        La MJC Lillebonne, implantée dans un bâtiment historique du centre de Nancy, est une **véritable fourmilière d’activités culturelles et de loisirs**.

        Elle propose :
        • plus d’une centaine d’activités pour enfants, ados et adultes
        • des expositions, conférences, spectacles, festivals… tout au long de l’année
        • un accueil de nombreuses associations et collectifs

        Au-delà des activités, Lillebonne porte un projet d’**éducation populaire** :
        • permettre aux jeunes et aux adultes de développer leur personnalité
        • prendre conscience de leurs aptitudes
        • se préparer à devenir des citoyens actifs et responsables

        C’est un lieu où l’on peut pratiquer, rencontrer, s’engager, et où naissent beaucoup de projets collectifs.
      MD
      link: "https://mjclillebonne.fr/activites-som/",
      when_line: "Activités et événements toute l’année"
    ),
    category: "rencontres",
    organization: "MJC Lillebonne",
    location: "14 Rue du Cheval Blanc, 54000 Nancy",
    time_commitment: "Activités régulières + événements ponctuels",
    is_active: true,
    tags: "mjc,culture,éducation populaire,loisirs",
    image_url: image_for("rencontres"),
    website: "https://mjclillebonne.fr/activites-som/",
    contact_phone: "03 83 36 82 82"
  }
]

# ===== REPAIR CAFÉS DU GRAND NANCY =====
nancy_opportunities += [
  {
    title: "Repair Café à Villers-lès-Nancy",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Un aspirateur à bout de souffle ? Une cafetière en carafe ? Un grille-pain cuit ? Le réseau des Repair Cafés du Grand Nancy est là pour ça.

        À la MJC Savine, des bricoleurs et bricoleuses bénévoles t’aident à réparer tes objets du quotidien, **avec toi**, pas à ta place. L’objectif : apprendre ensemble, échanger des savoir-faire, éviter de jeter ce qui peut encore servir.

        Ambiance conviviale, entrée libre, et satisfaction immense quand ton appareil repart pour quelques années.
      MD
      link: "https://mhdd.grandnancy.eu/actus-agenda/agenda/details-agenda?uuid=9cf27b54-4bfb-11ee-a51a-2dc944ed9ece",
      when_line: "Mercredis 26 novembre, 17 décembre, 28 janvier 2025"
    ),
    category: "ecologiser",
    organization: "MJC Savine",
    location: "3 Bd des Essarts, 54600 Villers-lès-Nancy",
    time_commitment: "Sessions ponctuelles — mercredis 26/11, 17/12, 28/01",
    is_active: true,
    tags: "repair café,réparation,anti-gaspi,convivialité",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Essey-lès-Nancy",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Un atelier chaleureux au Foyer Foch où habitants et bénévoles se retrouvent pour réparer électroménager, objets du quotidien et luminaires.

        Ici, on apprend par la pratique : guidé par des bricoleurs passionnés, tu découvres comment diagnostiquer une panne, démonter un appareil et lui offrir une seconde vie. L’ambiance est simple, conviviale, centrée sur l’entraide et la réduction des déchets.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Jeudis 11 décembre, 8 janvier, 12 février"
    ),
    category: "ecologiser",
    organization: "Foyer Foch",
    location: "Foyer Foch, 74 Avenue Foch, 54270 Essey-lès-Nancy",
    time_commitment: "Jeudis 11/12, 08/01, 12/02",
    is_active: true,
    tags: "repair café,électroménager,économie circulaire",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Tomblaine",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Tous les mardis, l’Espace Jean Jaurès se transforme en atelier collaboratif : tournevis, lampes, radios, vélos… chacun vient avec ce qu’il souhaite sauver.

        Le Repair Café rassemble habitants, étudiants et bénévoles autour de la réparation d’objets du quotidien. Les bénévoles prennent le temps d’expliquer, de montrer les gestes et de transmettre leur savoir-faire dans une ambiance détendue.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Chaque mardi de 17h à 19h"
    ),
    category: "ecologiser",
    organization: "Espace Jean Jaurès",
    location: "Espace Jean Jaurès, Tomblaine",
    time_commitment: "Tous les mardis, 17h–19h",
    is_active: true,
    tags: "repair café,réparation,vélos,convivialité",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café Nancy — Résidence Les Abeilles",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Un Repair Café urbain et dynamique au sein de la Résidence Habitat Jeunes Les Abeilles.

        Les ateliers en soirée attirent beaucoup de jeunes, curieux d’apprendre à réparer eux-mêmes leurs objets : petit électroménager, lampes, déco, petits appareils… C’est un lieu idéal pour s’initier au bricolage, comprendre les bases de l’électronique et rencontrer d’autres habitants dans une ambiance conviviale.
      MD
      link: "https://www.nancy.fr",
      when_line: "Jeudis 23 jan, 27 fév, 27 mars, 24 avr, 22 mai, 26 juin"
    ),
    category: "ecologiser",
    organization: "Résidence Habitat Jeunes Les Abeilles",
    location: "Résidence Les Abeilles, 58 rue de la République, 54000 Nancy",
    time_commitment: "Jeudis en soirée — plusieurs dates dans l’année",
    is_active: true,
    tags: "repair café,jeunesse,bricolage,électronique",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Saint-Max",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Un Repair Café familial accueilli au Centre Social Saint-Michel-Jéricho (espace Champlain).

        Les samedis matins, habitants du quartier et bénévoles se retrouvent pour remettre en état de petits appareils, outils ou objets cassés. L’objectif : apprendre ensemble, transmettre des compétences et éviter que des objets encore réparables ne finissent à la poubelle.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Samedis 20 déc, 17 jan, 21 fév"
    ),
    category: "ecologiser",
    organization: "Centre Social Saint-Michel-Jéricho",
    location: "Centre Social Saint-Michel-Jéricho, 75 rue Alexandre 1er, Saint-Max",
    time_commitment: "Samedis matin — plusieurs dates",
    is_active: true,
    tags: "repair café,quartier,entraide",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Heillecourt",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        À la Maison du Temps Libre, le Repair Café rassemble régulièrement des habitants désireux d’apprendre à réparer leurs objets.

        On y répare grille-pain, lampes, perceuses, mixers… avec l’aide de bénévoles expérimentés. C’est aussi un lieu d’échange où les participants prennent confiance en leurs capacités et découvrent l’importance du réemploi.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Mercredis 10 déc, 14 jan, 11 fév"
    ),
    category: "ecologiser",
    organization: "Maison du Temps Libre",
    location: "Maison du Temps Libre, 11 rue Gustave Lemaire, Heillecourt",
    time_commitment: "Mercredis — plusieurs sessions",
    is_active: true,
    tags: "repair café,réemploi,bricolage",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Houdemont",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Au Pôle Associatif de Houdemont, le Repair Café donne une seconde chance aux petits appareils, jouets et objets électriques.

        Les bénévoles accompagnent chaque réparation pas à pas et expliquent les bons gestes. C’est une initiative locale forte qui sensibilise au réemploi et à la lutte contre le gaspillage.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Mardis 16 déc, 20 jan"
    ),
    category: "ecologiser",
    organization: "Pôle Associatif de Houdemont",
    location: "Pôle Associatif, 12 bis rue des Saules, Houdemont",
    time_commitment: "Mardis — quelques dates",
    is_active: true,
    tags: "repair café,anti-gaspi,quartier",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Jarville-la-Malgrange",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Un Repair Café de quartier où habitants et bénévoles s’entraident pour prolonger la vie des objets.

        L’ambiance est détendue et pédagogique : chacun peut venir avec un appareil en panne, apprendre à l’ouvrir, comprendre ce qui ne va pas et tenter une réparation guidée. Un moment utile et convivial.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Mercredis 17 déc, 21 jan"
    ),
    category: "ecologiser",
    organization: "Réseau Repair Cafés du Grand Nancy",
    location: "Jarville-la-Malgrange",
    time_commitment: "Mercredis — quelques dates",
    is_active: true,
    tags: "repair café,quartier,apprentissage",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Laneuveville-devant-Nancy",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Le Repair Café local accueille régulièrement les habitants pour réparer ensemble leurs objets du quotidien.

        On y apprend à diagnostiquer une panne simple, manipuler des outils en sécurité et adopter les bons réflexes pour offrir une seconde vie à ce qui semblait perdu. Un geste écologique et collectif apprécié dans la commune.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Jeudis 4 déc, 8 jan, 5 fév"
    ),
    category: "ecologiser",
    organization: "Réseau Repair Cafés du Grand Nancy",
    location: "Laneuveville-devant-Nancy",
    time_commitment: "Jeudis — plusieurs dates",
    is_active: true,
    tags: "repair café,écologie,collectif",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Ludres",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Un Repair Café convivial où les bénévoles accompagnent les habitants dans la réparation de petits équipements domestiques.

        Les ateliers permettent à chacun de se familiariser avec les bases du bricolage et de l’électricité, dans un esprit de partage et de réduction des déchets.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Mardi 2 déc"
    ),
    category: "ecologiser",
    organization: "Réseau Repair Cafés du Grand Nancy",
    location: "Ludres",
    time_commitment: "Mardi 2 décembre",
    is_active: true,
    tags: "repair café,électricité,bricolage",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Pulnoy",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Au Centre de Rencontre de Pulnoy, le Repair Café propose des ateliers ouverts à tous : réparation d’appareils, petit bricolage, couture légère.

        Les participants viennent avec leurs objets cassés et repartent avec de nouvelles compétences et la satisfaction d’avoir évité un déchet supplémentaire.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Lundis 1 déc, 2 mars, 1er juin"
    ),
    category: "ecologiser",
    organization: "Centre de Rencontre de Pulnoy",
    location: "Centre de rencontre, avenue Léonard de Vinci (Résidences Vertes), Pulnoy",
    time_commitment: "Lundis — plusieurs dates dans l’année",
    is_active: true,
    tags: "repair café,couture,réparation",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Saulxures-lès-Nancy",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Organisé à la Mairie, le Repair Café de Saulxures accueille habitants et bénévoles pour réparer ensemble toutes sortes d’objets.

        De la bouilloire à la lampe en passant par les jouets, chaque séance est une occasion d’apprendre, de transmettre et de réduire notre impact environnemental.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Lundis 6 fév, 4 mai, 5 oct"
    ),
    category: "ecologiser",
    organization: "Mairie de Saulxures-lès-Nancy",
    location: "Mairie de Saulxures-lès-Nancy, 2 rue de Tomblaine",
    time_commitment: "Lundis — plusieurs dates",
    is_active: true,
    tags: "repair café,mairie,écoresponsable",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Seichamps",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        Un Repair Café de proximité où l’on apprend à réparer au lieu de jeter : petit électroménager, éclairage, petits appareils domestiques.

        Les bénévoles partagent leurs compétences, expliquent les gestes simples et encouragent chacun à devenir plus autonome face aux objets du quotidien.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Lundi 5 jan, mardi 7 avr, lundi 7 sept"
    ),
    category: "ecologiser",
    organization: "Réseau Repair Cafés du Grand Nancy",
    location: "Seichamps",
    time_commitment: "Plusieurs dates entre janvier et septembre",
    is_active: true,
    tags: "repair café,autonomie,électroménager",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café à Vandœuvre-lès-Nancy",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        À la MJC Lorraine, le Repair Café attire bricoleurs confirmés et habitants curieux.

        Les ateliers sont rythmés et très vivants : un mélange de partage de compétences, de dépannage pratique et d’apprentissage collectif. On y traite une grande variété d’objets dans une ambiance chaleureuse.
      MD
      link: "https://mhdd.grandnancy.eu",
      when_line: "Lundis mensuels"
    ),
    category: "ecologiser",
    organization: "MJC Lorraine",
    location: "MJC Lorraine, 1 rue de Lorraine, Vandœuvre-lès-Nancy",
    time_commitment: "Lundis — ateliers mensuels",
    is_active: true,
    tags: "repair café,mjc,collectif",
    image_url: image_for("ecologiser")
  },
  {
    title: "Repair Café du quartier 3B à Nancy",
    description: build_description(
      category: "ecologiser",
      base_desc: <<~MD,
        À la MJC Beauregard, le Repair Café du quartier 3B est un rendez-vous local apprécié.

        Les habitants y amènent appareils en panne, outils, lampes ou objets divers. Soutenu par des bénévoles compétents, l’atelier met l’accent sur la transmission de savoir-faire et la réduction des déchets.
      MD
      link: "https://www.nancy.fr",
      when_line: "Samedis 6 déc, 10 jan, 7 fév"
    ),
    category: "ecologiser",
    organization: "MJC Beauregard",
    location: "MJC Beauregard, Place Maurice Ravel, 54000 Nancy",
    time_commitment: "Samedis — plusieurs dates",
    is_active: true,
    tags: "repair café,quartier,savoir-faire",
    image_url: image_for("ecologiser")
  }
]

# =================== Belles histoires (Stories) ===================

nancy_stories = [
  {
    title: "Aurélie ouvre L’Écrin à Damelevières",
    chapo: "Aurélie a quitté la fonction publique pour créer L’Écrin, un bar lounge chaleureux à Damelevières. Une histoire de courage, de doutes… et de rencontres. ✨",
    description: "Aurélie, ex-fonctionnaire, a osé tout quitter pour ouvrir L’Écrin, un bar lounge convivial à Damelevières. Son histoire montre qu’on peut réinventer son quotidien, même loin des grandes villes.",
    body: <<~MD,
      ### Quand l’envie de changer devient trop forte

      Pendant des années, Aurélie a travaillé dans la fonction publique. Un emploi stable, rassurant, mais qui la laissait de plus en plus sur sa faim. L’idée de créer un lieu à elle, où les gens viendraient se détendre et se retrouver, revenait régulièrement. Peu à peu, ce n’était plus juste un rêve, mais un besoin : avoir un projet qui lui ressemble vraiment. 💭

      Elle commence à imaginer un bar lounge cosy, avec une ambiance feutrée, des lumières douces, des planches à partager et une carte qui donne envie de prendre le temps.

      ### De la sécurité au grand saut

      Quitter un poste stable pour ouvrir un commerce dans une petite ville, ce n’est pas anodin. Aurélie se forme, se fait accompagner, travaille son dossier et son prévisionnel. Elle passe des soirées à comparer les banques, à chercher le bon local, à comprendre les normes, les licences, les travaux.

      Les doutes sont là : est-ce que les habitants répondront présent ? Est-ce que le projet tiendra dans la durée ? Mais à un moment, il faut trancher : elle signe. Les travaux commencent, et L’Écrin commence enfin à exister ailleurs que dans sa tête. 🔨

      ### Un lieu pour faire une pause… et se rencontrer

      Quand on pousse la porte de L’Écrin, on découvre un bar à l’atmosphère chaleureuse : banquettes confortables, déco travaillée, lumières tamisées. On y vient pour prendre un verre, grignoter, fêter un anniversaire ou juste décompresser après le travail.

      Au fil des semaines, Aurélie voit se créer ce qu’elle avait imaginé : des habitués qui reviennent, des groupes d’amis qui se retrouvent, des gens qui ne se seraient peut-être jamais rencontrés ailleurs. Son bar devient un petit repère dans la ville, un endroit où l’on sait qu’on sera accueilli.

      ### Ce que tu peux en retenir

      • partir d’un emploi très sécurisé pour construire un projet plus aligné avec ses envies
      • créer un lieu de vie même en dehors des grandes métropoles
      • s’appuyer sur l’accompagnement (banque, réseaux locaux, proches) pour franchir les étapes une par une

      Si tu rêves d’ouvrir un café, un bar, un commerce de proximité, son parcours rappelle que ce n’est jamais « trop tard » pour se lancer — à condition d’accepter un peu d’incertitude et beaucoup d’apprentissage en route. 🌟
    MD
    quote: "J’avais envie de créer quelque chose de différent du simple bistrot.",
    location: "L’Écrin — Damelevières (54)",
    latitude: 48.5568,
    longitude: 6.3860,
    image_url: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?q=80&w=1600&auto=format&fit=crop",
    source_name: "Est Républicain",
    source_url: nil
  },

  {
    title: "Laure crée Galapaga, concept store éthique à Villers-lès-Nancy",
    chapo: "Après plusieurs années dans un parcours plus classique, Laure a ouvert Galapaga, un concept store éthique et éco-responsable à Villers-lès-Nancy. Un lieu qui raconte une autre façon de consommer. 🌱",
    description: "Avec Galapaga, Laure propose un concept store éthique à Villers-lès-Nancy : marques engagées, sélection exigeante et envie de montrer qu’on peut consommer autrement, sans renoncer au plaisir.",
    body: <<~MD,
      ### L’envie de donner du sens à son travail

      Laure a longtemps travaillé dans un univers plus traditionnel, avec des journées bien remplies mais un sentiment qui revenait souvent : « Est-ce que ce que je fais a vraiment du sens pour moi ? ». Peu à peu, elle s’intéresse aux marques responsables, à la consommation éthique, aux alternatives plus respectueuses de l’environnement et des personnes.

      Elle se met à suivre des créateurs, des petites marques engagées, des projets qui allient esthétique et impact positif. L’idée d’un concept store commence à germer : un lieu où rassembler ces marques, les rendre visibles, et donner aux habitants des options concrètes pour consommer autrement.

      ### Trois ans pour faire mûrir un projet

      Laure a travaillé son concept, son positionnement, la sélection de marques, les prix… Elle a aussi dû apprendre un nouveau métier : négocier avec des fournisseurs, chercher un local, construire une identité visuelle, imaginer l’expérience client en boutique.

      Elle résume ce chemin en une phrase : beaucoup de patience, de travail en coulisses et la conviction que le projet en vaut la peine. ✨

      ### Un concept store engagé, sans être culpabilisant

      Galapaga propose :
      • des vêtements et accessoires responsables
      • des objets du quotidien durables
      • des produits transparents sur leur fabrication

      Laure prend le temps de raconter l’histoire derrière chaque marque. Le but : proposer des alternatives concrètes, sans culpabiliser.

      ### Ce que tu peux en retenir

      • un projet peut naître d’un malaise diffus puis se préciser
      • le commerce peut mêler esthétique, impact écologique et engagement social
      • un lieu engagé peut devenir un repère local

      Un projet construit avec patience, conviction et sens. 🌈
    MD
    quote: "Il m’a fallu trois ans pour concrétiser ce projet qui a mûri en moi.",
    location: "Galapaga — Villers-lès-Nancy (54)",
    latitude: 48.6733,
    longitude: 6.1532,
    image_url: "https://images.unsplash.com/photo-1526481280695-3c687fd543c0?q=80&w=1600&auto=format&fit=crop",
    source_name: "Est Républicain",
    source_url: nil
  }
]

puts "🌱 Nettoyage et import des opportunités Nancy..."

nancy_opportunities.each do |attrs|
  Opportunity.find_or_create_by!(
    title: attrs[:title],
    location: attrs[:location]
  ) do |opportunity|
    opportunity.assign_attributes(attrs)
  end
end

puts "✅ Opportunités seedées"
puts "📍 #{Opportunity.count} opportunités dans la base"
puts "   - Bénévolat : #{Opportunity.where(category: 'benevolat').count}"
puts "   - Formation : #{Opportunity.where(category: 'formation').count}"
puts "   - Rencontres : #{Opportunity.where(category: 'rencontres').count}"
puts "   - Entreprendre : #{Opportunity.where(category: 'entreprendre').count}"
puts "   - Écologiser : #{Opportunity.where(category: 'ecologiser').count}"

# ===== Import des belles histoires =====
puts "📖 Import des belles histoires..."

nancy_stories.each do |attrs|
  Story.find_or_create_by!(
    title: attrs[:title],
    location: attrs[:location]
  ) do |story|
    story.assign_attributes(attrs)
  end
end

puts "✅ Stories seedées"
puts "📖 #{Story.count} belles histoires dans la base"
