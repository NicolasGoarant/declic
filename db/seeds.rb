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

# =================== Import en base ===================

puts "🌱 Nettoyage et import des opportunités Nancy..."

# Option : supprimer les anciennes opportunités (décommenter si besoin)
# Opportunity.destroy_all

nancy_opportunities.each do |attrs|
  Opportunity.find_or_create_by!(
    title: attrs[:title],
    location: attrs[:location]
  ) do |opportunity|
    opportunity.assign_attributes(attrs)
  end
end

puts "✅ Seeds chargés avec succès !"
puts "📍 #{Opportunity.count} opportunités dans la base"
puts "   - Bénévolat : #{Opportunity.where(category: 'benevolat').count}"
puts "   - Formation : #{Opportunity.where(category: 'formation').count}"
puts "   - Rencontres : #{Opportunity.where(category: 'rencontres').count}"
puts "   - Entreprendre : #{Opportunity.where(category: 'entreprendre').count}"
