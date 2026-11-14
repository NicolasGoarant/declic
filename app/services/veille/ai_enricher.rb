# frozen_string_literal: true

module Veille
  # Propose, pour un élément brut : son type (opportunité ou belle histoire, selon
  # la règle éditoriale), sa famille (dont le code déduit la catégorie Déclic), sa commune, sa date
  # ou son régime, et un résumé reformulé en deux phrases. Écarte (sans publier
  # quoi que ce soit) ce qui est hors ligne, hors périmètre (Veille::Territoire) ou passé ;
  # ce qui n'a aucune commune reste à localiser.
  #
  # Haiku suffit : tâche de classification sur un texte court, en lot.
  class AiEnricher < AiPass
    # Modèle du tri : ENV["VEILLE_MODEL"] (Haiku 5.5 par défaut). Seconde passe sur les scores
    # incertains (40 à 70 sur 100, soit 0,4 à 0,7) : ENV["VEILLE_MODEL_ESCALADE"] (Sonnet 5.5 par défaut ; Opus reste possible par configuration).
    DEFAUT_MODEL    = "claude-haiku-5-5"
    DEFAUT_ESCALADE = "claude-sonnet-5-5"
    MODEL        = DEFAUT_MODEL
    ESCALADE_MIN = 40
    ESCALADE_MAX = 70
    PASSE        = "enrichissement"
    TIMEOUT      = 30
    OPEN_TIMEOUT = 5
    RETRIES      = 1
    # Large : la réflexion adaptative des modèles 5.x compte dans max_tokens (une réponse tronquée est illisible).
    MAX_TOKENS   = 4000
    # Plafond de texte envoyé : borne le coût, et une fiche d'agenda ou une annonce n'en demande pas plus.
    MAX_TEXTE    = 3_000
    # Citation maximale autorisée dans un résumé, en mots.
    MAX_CITATION = 15
    # Sources officielles : ce qu'elles publient invite par nature à agir.
    SOURCES_OPPORTUNITES = %w[jeveuxaider agenda_nancy transentreprise].freeze

    # La catégorie reste celle de ces sources ; les autres la tirent de la famille.
    SOURCES_CATEGORIE_FIXE = %w[jeveuxaider transentreprise].freeze

    FAMILLES_HISTOIRE    = %w[reconversion creation resilience engagement vocation portrait].freeze
    FAMILLES_OPPORTUNITE = ::Opportunity::FAMILLES.keys.freeze
    HORS_LIGNE           = "hors_ligne"
    # Hors périmètre Déclic : loisir ou sortie sans engagement, apprentissage, rencontre ni écologie. Écarté, raison distincte de « Hors ligne éditoriale ».
    HORS_PERIMETRE       = "hors_perimetre"
    # Catégorie (donc couleur du pin) déduite par le code, pour qu'elle ne contredise jamais la famille.
    CATEGORIE_PAR_FAMILLE = {
      "s_engager" => "benevolat", "evenement_solidaire" => "benevolat", "agir_ecologie" => "ecologie",
      "entreprendre" => "entreprendre", "se_former" => "formation", "pratiquer" => "pratiquer",
      "rencontre" => "pratiquer", "lieu_collectif" => "pratiquer", "decouvrir" => "decouvrir",
      "petite_manifestation" => "decouvrir"
    }.freeze
    # Rubrique de l'Agenda Grand Nancy : signal sûr, indépendant du modèle.
    RUBRIQUE_BROCANTE = /\bbrocante\b/i

    SCHEMA = {
      type: "object",
      properties: {
        type:        { type: "string", enum: Veille::Candidate::ITEM_TYPES },
        role_public: { type: "string", enum: %w[contributeur apprenant participant spectateur lecteur] },
        famille:     { type: "string", enum: FAMILLES_HISTOIRE + FAMILLES_OPPORTUNITE + [HORS_LIGNE, HORS_PERIMETRE] },
        zone:        { type: "string", enum: %w[grand_nancy bassin_nancy grand_est ailleurs inconnue] },
        commune:     { type: "string" },
        lieu:        { type: "string" },
        date_debut:  { type: "string" },
        date_fin:    { type: "string" },
        regime:      { type: "string" },
        resume:      { type: "string" },
        hors_ligne:  { type: "boolean" },
        confiance:   { type: "integer" }, # 0-100 : bornée par #apply (l'API refuse minimum/maximum)
        motif:       { type: "string" }
      },
      required: %w[type role_public famille zone commune lieu date_debut date_fin regime resume hors_ligne confiance motif],
      additionalProperties: false
    }.freeze

    SYSTEM_PROMPT = <<~TXT.freeze
      Tu es assistant éditorial de Déclic, plateforme du Grand Nancy dont la promesse est « Change ta vie, en quelques clics » : aider chacun à s'engager, entreprendre, se former, agir pour l'écologie, pratiquer, découvrir, et s'inspirer de ceux qui ont franchi le pas. On te donne un élément repéré sur une source publique. Tu le classes et tu le résumes. Un humain relira tout.

      PRINCIPE : tu décris plus que tu n'élimines. Un événement local ouvert au public reste dans la base, même si l'on y vient surtout pour écouter ou flâner : sa famille dit ce qu'il est, et l'humain décide de ce qu'il affiche. Hors ligne reste l'exception, réservée à la liste ci-dessous, dont fait partie l'actualité municipale qui ne propose rien à faire. Un événement daté, où le lecteur peut se rendre, s'inscrire ou participer à un moment précis, n'est jamais hors ligne : c'est une opportunité éventuelle. Seule la règle HORS PÉRIMÈTRE DÉCLIC peut encore l'écarter.

      ANNONCE OU ACTUALITÉ : les sources communales mélangent les deux, et le texte est souvent tronqué. Avant tout, demande-toi si le titre annonce quelque chose à quoi le lecteur peut se rendre, s'inscrire ou participer (une conférence, un défilé, une expo-vente, un atelier, un appel à bénévoles, des inscriptions ouvertes) ou s'il informe seulement. Sont de l'actualité, donc hors_ligne, même sans autre détail : « Route de Bosserville : fermée du 19 au 23/10 » (travaux), « Le dernier Journal de Maxéville est arrivé » (parution), « Prime Air Bois » (dispositif d'aide), « Maxéville : Ville Libre sans Tabac » (engagement de la commune), « Police municipale : arrivée d'un nouvel agent », un arrêté, une campagne de prévention. Sont aussi hors_ligne les comptes rendus au passé (« Un succès bien brassé pour la Fête de la bière », « Chantiers jeunes : coup de neuf… » où six jeunes « ont participé », « Les jeunes du CME à la découverte du Sénat »). Un texte maigre n'est pas une raison de garder : seul un titre qui annonce un rendez-vous ou un appel à agir se garde, à confiance basse.

      TYPE
      - « belle_histoire » : un récit centré sur une personne, un duo ou un collectif nommés et vivants aujourd'hui : d'où ils viennent, ce qui les a décidés, l'épreuve traversée, ce qu'ils ont construit, ou une vie qui inspire. Un texte qui raconte ce qu'une personne nommée a lancé ou créé, sans date ni rendez-vous, est une belle histoire. Si le texte raconte surtout une personne, un gala ou un appel aux dons mentionnés en passant ne change pas le type.
      - « opportunite » : le lecteur peut y aller ou agir lui-même : donner de son temps, participer, candidater, reprendre, apprendre, rejoindre, assister. Date, régime permanent ou lieu ouvert, peu importe. Une annonce d'événement n'est jamais une belle histoire : dès que le texte donne une date, un lieu ou une réservation, ou que sa rubrique est « Conférence - Rencontre », c'est une opportunité, même si le titre nomme une personne.

      ROLE_PUBLIC (décide d'abord du type, puis du rôle) :
      Pour une belle histoire, le rôle vaut toujours « lecteur ».
      Pour une opportunité, que fait concrètement le lecteur s'il y répond ?
      - contributeur : il donne du temps, de l'argent, des objets ; il répare, il reprend, il candidate, il rejoint durablement un collectif ; il participe à un événement dont la recette ou l'action sert explicitement une cause
      - apprenant : il repart avec un savoir-faire ou une compétence qu'il a pratiqués
      - participant : il échange et construit quelque chose avec les autres présents (fresque, débat citoyen, assemblée, café des langues, meetup)
      - spectateur : il écoute, regarde, visite, achète ou flâne
      Le rôle décrit l'élément : il n'entraîne jamais à lui seul la mise hors ligne.

      FAMILLE (obligatoire, une seule)
      Pour une belle histoire :
      - reconversion : quitter un métier ou une vie pour une autre
      - creation : créer un commerce, une entreprise, une start-up ou une innovation locale, en expliquant d'où elle vient et quel problème elle résout
      - resilience : se reconstruire après la maladie, le handicap, l'exil, une faillite
      - engagement : agir pour les autres ou pour l'environnement, à titre associatif ou collectif
      - vocation : un parcours d'artisan, d'artiste, de chef, porté par une passion
      - portrait : une personne attachante racontée pour sa vie ou son âge, sans rupture ni création (une centenaire, un bénévole de toujours)
      Pour une opportunité :
      - s_engager : bénévolat, don, collecte, chantier, mission, rejoindre une association
      - agir_ecologie : réparer, réemployer, composter, AMAP, jardin partagé, Repair Café, atelier vélo, sensibilisation au tri
      - entreprendre : reprise ou cession d'entreprise, concours, financement, incubateur, accompagnement, appel à projets
      - se_former : formation à visée professionnelle ou linguistique pour adultes, dans la durée (cursus, certification, reconversion, GRETA, cours de langue suivis)
      - pratiquer : activité ponctuelle ou de loisir où l'on fait soi-même, pour adultes, familles ou enfants (atelier d'une journée ou d'un week-end, initiation, stage de découverte, cours de pratique de loisir)
      - lieu_collectif : lieu à rejoindre durablement (MJC, maison de quartier, studio associatif, collectif, réseau)
      - evenement_solidaire : la participation finance ou sert explicitement une cause
      - rencontre : on échange et on construit avec les autres présents (rôle participant) ; une conférence-rencontre où l'on vient surtout écouter relève de decouvrir
      - decouvrir : conférence, débat, rencontre d'auteur, projection-débat, répétition ouverte, visite guidée, exposition commentée ou médiation : on écoute et on apprend quelque chose
      - petite_manifestation : vide-grenier, brocante, marché, foire, salon, bourse aux objets, loto, fête ou soirée festive, sans cause explicite ni enjeu d'engagement. Le titre ou la rubrique doit le dire : cette famille ne sert jamais de solution de repli pour un texte qu'on ne comprend pas.
      Pour un contenu hors ligne : hors_ligne.

      CATÉGORIE : le code la déduit de ta famille ; choisis donc la famille selon ce critère.
      - Pratiquer (familles pratiquer, rencontre, lieu_collectif) : la personne est actrice ou participante directe : ateliers, activités manuelles, rejoindre un collectif ou un groupe, pratiquer une activité avec d'autres.
      - Découvrir (familles decouvrir, petite_manifestation) : la personne vient voir, visiter ou assister : visites guidées, expositions, conférences, événements type brocantes, foires ou fêtes, choses à observer plus qu'à faire soi-même.

      SE_FORMER OU PRATIQUER : regarde d'abord la nature, puis la durée. Visée professionnelle, langue suivie, certification, reconversion : se_former. Loisir, découverte, enfants ou familles, une séance, une journée, un week-end, cours de loisir même étalés sur plusieurs mois : pratiquer, même si l'activité s'appelle atelier, cours, stage ou formation et même si l'on y apprend quelque chose. Une rubrique « Atelier » n'est jamais se_former. Une série d'ateliers de même intitulé reçoit la même famille à chaque date.

      TEXTE MAIGRE : un titre et une rubrique suffisent. Un intitulé « Atelier », une rubrique « Atelier / jeux », une activité en médiathèque ou en ludothèque désignent une activité où l'on participe : pratiquer si l'on fait soi-même, decouvrir si l'on écoute. Sans aucun indice : decouvrir. Tu ne mets jamais hors ligne faute de détails : garde, choisis la famille la plus probable d'après le titre et la rubrique, et baisse la confiance sous 50.

      HORS LIGNE (hors_ligne = true, famille = « hors_ligne »)
      Pour tous les contenus :
      - faits divers, actualité judiciaire, résultats sportifs, comptes rendus de conseils, mouvements sociaux, annonces institutionnelles, travaux, carnet (mariages, décès, anniversaires), santé grand public sans événement, événement annulé.
      - actualité municipale ou administrative qui informe sans inviter à y aller ni à agir : parution d'un journal ou d'un bulletin, arrivée ou nomination d'un agent, arrêté, fermeture de route, dispositif ou aide (prime, subvention, démarche, guichet), campagne de prévention ou de vaccination, engagement de la commune (label, charte), planning de service.
      - compte rendu d'un événement ou d'un chantier déjà terminé, écrit au passé (« a réuni », « ont participé », « un succès », « a pris des airs de… », « les jeunes ont découvert… ») : il n'y a plus rien à faire, et il ne raconte pas une personne nommée, donc ce n'est pas non plus une belle histoire.
      Test pour trancher entre annonce d'opportunité et actualité : le lecteur peut-il, après lecture, se rendre quelque part, s'inscrire, candidater, donner ou participer à un moment précis ou régulier ? Si oui, c'est une opportunité (même maigre : baisse alors la confiance). Si le texte ne fait que renseigner ou rendre compte, hors ligne.
      - simple nomination sans parcours ni initiative.
      Pour un récit :
      - aucune personne ou collectif nommé (« quatre adolescents », « des bénévoles » ne suffisent pas), ou le texte rend compte d'une animation ponctuelle sans raconter personne ;
      - rien dont le lecteur puisse s'inspirer : l'élément ne montre aucune démarche d'une personne vivante ;
      - le sujet est une institution, ou une personne morte ou d'une époque passée, même redécouverte ou honorée aujourd'hui. Ce n'est jamais un portrait.
      Le portrait d'une jeune entreprise locale reste valable s'il dit d'où elle vient et quel problème elle résout. Un récit n'a pas à proposer d'action : c'est la démarche racontée qui compte. On n'écarte jamais un récit parce qu'il n'appelle à aucune action, parce qu'il se passe hors du Grand Nancy, parce qu'il parle d'un commerce ou parce qu'il donne peu de détails.
      Pour une opportunité :
      - spectacle, concert, récital ou film sans échange ni cause explicite ;
      - événement réservé à une profession ou à des cadres (congrès, colloque de directeurs, réunion de branche) ;
      - lancement d'un service ou d'une plateforme en ligne sans lieu ni action locale dans le texte, même si le texte est tronqué ;
      - section, école ou cours d'un club sportif, même ouverts à de nouveaux membres ;
      - fiche de catalogue d'un organisme de formation : une fiche par diplôme, titre ou stage (bac pro, BTS, licence, titre professionnel, habilitation électrique, logiciel), destinée aux élèves en filière ou aux salariés envoyés par leur entreprise. Reste valable une offre présentée comme une porte d'entrée pour un adulte qui veut changer de voie.
      - aucune action possible : le texte rend compte d'une actualité (lancement, bilan, succès passé) sans rien que le lecteur puisse faire. Une date et un lieu suffisent, car y aller est une action, même pour écouter. Une activité régulière ouverte au public suffit aussi, même sans date ni contact. Un texte d'agenda n'entre donc jamais dans ce cas.
      Tout événement au profit d'une cause reste valable, même si l'on y écoute ou l'on y dîne : rôle contributeur, famille evenement_solidaire. Un vide-grenier au profit d'une cause est un evenement_solidaire ; sans cause, c'est une petite_manifestation, jamais hors ligne.

      HORS PÉRIMÈTRE DÉCLIC (famille = « hors_perimetre », hors_ligne = false)
      Un loisir ou une sortie culturelle qui n'a AUCUNE dimension d'engagement (agir, aider, donner, contribuer), d'apprentissage (acquérir un savoir-faire utile), de rencontre (échange, débat, rendez-vous avec des acteurs locaux) ni d'écologie (climat, énergie, mobilité, nature, jardin, réemploi) est hors périmètre : visite ou exposition à regarder, animation ou bricolage pour passer le temps, atelier créatif de pur loisir, spectacle de saison. Ce n'est pas de l'actualité (donc pas hors ligne) : c'est un événement réel qui n'entre pas dans la promesse de Déclic, et il est écarté. Dès qu'une des quatre dimensions est présente, même discrète (don de sang, fête de l'énergie, jardinage, mobilité, santé collective), garde-le avec sa famille habituelle. En cas de doute, garde et baisse la confiance.
      Exemples, titres seuls : « Don de sang festif » et « Fête de l'Énergie et du Climat » sont gardés ; « Visite flash de l'exposition Émile Gallé » et « Lanternes effrayantes » sont hors périmètre.

      ZONE (lieu d'ancrage réel, pas celui de la source) : grand_nancy (les 20 communes de la Métropole), bassin_nancy (reste de la Meurthe-et-Moselle : Toul, Lunéville, Pont-à-Mousson, Pompey…), grand_est (reste de la Lorraine et du Grand Est : Metz, Épinal, Bar-le-Duc, Strasbourg…), ailleurs, inconnue. La zone décrit ; elle n'écarte rien.

      COMMUNE : la commune d'ancrage telle que le texte la donne, dans ou hors du Grand Nancy. Chaîne vide si le texte ne la donne pas. Tu ne la devines pas depuis le nom de la source.

      LIEU : le nom du lieu où se tient l'événement, tel que la source l'indique (« Musée des Beaux-Arts », « Salle Poirel », « 12 rue Saint-Dizier »), sans la commune. Chaîne vide si la source n'en donne pas : tu ne le devines jamais. Une commune seule n'est pas un lieu.

      DATES : date_debut et date_fin au format AAAA-MM-JJ, uniquement si le texte les donne. Quand le texte ne donne pas l'année, c'est celle de la date de publication indiquée, ou la suivante si le jour est antérieur à cette publication et que le texte parle d'un événement à venir : tu n'inventes jamais une année antérieure à la publication. Un événement dont la date précède la date du jour est passé. Pas de date : chaînes vides, et « regime » dit en quelques mots le régime (« Ouvert toute l'année », « Sur rendez-vous »…) ; sinon regime est vide.

      RÉSUMÉ : exactement deux phrases, en français, reformulées avec tes propres mots. Au plus 15 mots consécutifs identiques à la source. Ni emoji, ni emphase, ni formule d'accroche. Les noms propres, lieux, dates et chiffres se reprennent tels quels.

      confiance (0-100) : ta certitude sur le type, la famille et la zone ensemble. motif : une phrase qui dit ce qui t'a fait trancher, ou ce qui manque.

      Réponds UNIQUEMENT par l'objet JSON demandé.
    TXT

    def self.model          = ENV["VEILLE_MODEL"].presence || DEFAUT_MODEL
    def self.model_escalade = ENV["VEILLE_MODEL_ESCALADE"].presence || DEFAUT_ESCALADE

    # Effort bas : classer un texte court n'a pas besoin de réflexion longue. Réglable par VEILLE_EFFORT ;
    # absent pour les modèles qui ne le connaissent pas (Haiku 4.5 et antérieurs).
    def self.effort_pour(modele)
      return nil unless modele.to_s.match?(/(sonnet|opus|haiku|fable)-5/)

      ENV["VEILLE_EFFORT"].presence || "low"
    end

    # Pur : paramètres de requête, sans réseau.
    def self.prompt_for(title:, text:, origin: nil, commune: nil, starts_on: nil, ends_on: nil, schedule_text: nil,
                        published_on: nil, today: nil)
      lignes = ["Titre : #{title.to_s.strip}"]
      lignes << "Date du jour : #{today}"                  if today
      lignes << "Date de publication de la source : #{published_on}" if published_on
      lignes << "Source : #{Veille::Candidate.origine_label(origin)}" if origin.present?
      lignes << "Commune indiquée par la source : #{commune}"        if commune.present?
      lignes << "Début : #{starts_on}" if starts_on
      lignes << "Fin : #{ends_on}"     if ends_on
      lignes << "Régime : #{schedule_text}" if schedule_text.present?
      lignes << ""
      lignes << "Texte récupéré :"
      lignes << text.to_s.squish.slice(0, MAX_TEXTE)

      json_schema_params(system: SYSTEM_PROMPT, user: lignes.join("\n"), schema: SCHEMA, max_tokens: MAX_TOKENS)
    end

    def self.params_pour(modele, params)
      effort = effort_pour(modele)
      return params unless effort

      params.merge(output_config: params[:output_config].merge(effort: effort))
    end

    # Interroge le modèle, applique la réponse au candidat et l'enregistre.
    # Lève AnthropicClient::Error ou AiPass::ParseError : l'appelant décide.
    def enrich(candidate, today: Date.current)
      params = self.class.prompt_for(
        title: candidate.title, text: candidate.full_text.presence || candidate.excerpt, origin: candidate.origin,
        commune: candidate.commune, starts_on: candidate.starts_on, ends_on: candidate.ends_on,
        schedule_text: candidate.schedule_text, published_on: candidate.published_on, today: today
      )
      result = run(self.class.params_pour(self.class.model, params), candidate: candidate)
      apply(candidate, result, today: today)
      escalader(candidate, params, today: today)
      candidate
    end

    # Consommation de tous les appels du dernier #enrich (premier passage + escalade éventuelle).
    def usages = @usages ||= []

    def escalade_utile?(candidate)
      candidate.score&.between?(ESCALADE_MIN, ESCALADE_MAX) && self.class.model_escalade != self.class.model
    end

    # Applique la réponse du modèle au candidat. Public et sans réseau : c'est là
    # que vivent les règles de classification et d'élimination, testées à part.
    def apply(candidate, result, today: Date.current)
      type = result["type"].to_s
      type = "opportunite" if SOURCES_OPPORTUNITES.include?(candidate.origin) && candidate.item_type != "belle_histoire"
      type = candidate.item_type.presence || "opportunite" unless Veille::Candidate::ITEM_TYPES.include?(type)
      manuel = candidate.classement_manuel? && candidate.item_type.present?
      type = candidate.item_type if manuel # un classement posé à la main reste prioritaire

      commune = localiser(candidate, result)
      famille = famille_pour(type, candidate, result)
      debut   = date_plausible(parse_date(result["date_debut"]), candidate) || candidate.starts_on
      fin     = date_plausible(parse_date(result["date_fin"]), candidate)   || candidate.ends_on
      # Repli : ce que le texte dit en français quand ni la source ni le modèle n'ont rien donné. Une date passée
      # trouvée ainsi est ignorée (une date d'archive citée dans un article ne doit pas écarter l'élément).
      lu = Veille::DatesFrancais.analyser("#{candidate.title}. #{candidate.full_text.presence || candidate.excerpt}".slice(0, 3000),
                                          reference: candidate.published_on || today)
      if debut.nil? && fin.nil?
        debut = lu.starts_on if lu.starts_on && lu.starts_on >= today
        fin   = lu.ends_on   if lu.ends_on && lu.ends_on >= today
      end

      attrs = {
        adresse: lieu_pour(candidate, result, commune),
        item_type: type, famille: famille, role_public: result["role_public"].presence, zone: result["zone"].presence,
        declic_category: (manuel ? candidate.declic_category : categorie_pour(type, candidate, famille)), commune: commune || candidate.commune,
        starts_on: debut, ends_on: fin,
        start_time: candidate.start_time || lu.start_time, end_time: candidate.end_time || lu.end_time,
        schedule_text: result["regime"].presence || candidate.schedule_text.presence || lu.periodicite,
        score: Integer(result["confiance"], exception: false)&.clamp(0, 100),
        reason: result["motif"].to_s.strip.presence,
        enriched_at: Time.current
      }
      resume = result["resume"].to_s.squish
      if self.class.copie_excessive?(resume, candidate.full_text.to_s + " " + candidate.title.to_s)
        attrs[:summary] = nil
        attrs[:status]  = "a_verifier"
        attrs[:reason]  = "Résumé trop proche de la source (plus de #{MAX_CITATION} mots d'affilée) : à réécrire. #{attrs[:reason]}".squish
      else
        attrs[:summary] = resume.presence
      end

      if manuel
        # Retenu par un humain : ni « hors ligne » ni « hors périmètre » ne l'écartent (le territoire et les dates, si).
      elsif famille == HORS_PERIMETRE
        attrs[:discard_reason] = "Hors périmètre Déclic : #{attrs[:reason] || 'loisir sans engagement, apprentissage, rencontre ni écologie'}".squish
        attrs[:status] = "ecarte"
      elsif famille == HORS_LIGNE
        attrs[:discard_reason] = "Hors ligne éditoriale : #{attrs[:reason] || 'hors de la ligne de Déclic'}".squish
        attrs[:status] = "ecarte"
      end
      if attrs[:status] == "ecarte"
        # déjà écarté pour sa famille
      elsif commune ? !Veille::Territoire.admis?(commune, type) : commune_nommee?(candidate, result)
        perimetre = type == "opportunite" ? "Meurthe-et-Moselle" : "Grand Est"
        attrs[:discard_reason] = "Hors #{perimetre}"
        attrs[:status] = "ecarte"
      elsif (fin || debut)&.<(today)
        attrs[:discard_reason] = "Événement passé"
        attrs[:status] = "ecarte"
      end
      # Sans aucune commune, l'élément reste dans la file, à localiser (Candidate.a_localiser).

      candidate.update!(attrs)
    end

    # Vrai si `resume` reprend plus de MAX_CITATION mots consécutifs de `source`.
    def self.copie_excessive?(resume, source, max: MAX_CITATION)
      Veille::Text.copie_excessive?(resume, source, max: max)
    end

    private

    # Second passage, avec le modèle plus fort, sur un score incertain. Son avis remplace le premier ;
    # un élément écarté au premier passage peut donc revenir dans la file.
    def escalader(candidate, params, today:)
      @usages = [usage]
      return unless escalade_utile?(candidate)

      modele = self.class.model_escalade
      premier = candidate.score
      result = run(self.class.params_pour(modele, params), candidate: candidate, model: modele, passe: "escalade")
      @usages << usage
      candidate.update!(status: "pending", discard_reason: nil) if candidate.ecarte?
      apply(candidate, result, today: today)
      candidate.update!(reason: "Second avis (#{modele}, premier score #{premier}) : #{candidate.reason}".squish.slice(0, 500))
    end

    # Nom de lieu relevé par l'IA, utilisé comme « Adresse » (géocodée à la validation). Agenda Grand
    # Nancy seulement : la presse n'a pas de texte source lu automatiquement. Jamais d'écrasement d'une
    # saisie à la main ; une commune seule n'est pas un lieu.
    def lieu_pour(candidate, result, commune)
      return candidate.adresse if candidate.origin != "agenda_nancy" || candidate.adresse.present?

      lieu = result["lieu"].to_s.squish
      return nil if lieu.blank? || Veille::Text.normalize(lieu) == Veille::Text.normalize(commune || candidate.commune)

      lieu.slice(0, 200)
    end

    # Si le modèle ne donne pas de commune reconnue, le code la cherche lui-même,
    # dans le titre d'abord, le texte ensuite.
    def localiser(candidate, result)
      Veille::Territoire.canonique(result["commune"]) ||
        Veille::Territoire.canonique(candidate.commune) ||
        Veille::Territoire.trouver_dans(candidate.title) ||
        Veille::Territoire.trouver_dans(candidate.full_text.presence || candidate.excerpt)
    end

    # Une commune a été nommée, mais elle n'est pas dans le Grand Est : ce n'est pas un élément à localiser.
    def commune_nommee?(candidate, result)
      result["commune"].to_s.strip.present? || candidate.commune.present?
    end

    def famille_pour(type, candidate, result)
      famille = result["famille"].to_s
      return HORS_LIGNE if result["hors_ligne"] == true || famille == HORS_LIGNE
      return HORS_PERIMETRE if famille == HORS_PERIMETRE
      return famille if type == "belle_histoire" && FAMILLES_HISTOIRE.include?(famille)
      return nil if type == "belle_histoire"
      return "petite_manifestation" if famille != "evenement_solidaire" && brocante_d_agenda?(candidate)

      famille if FAMILLES_OPPORTUNITE.include?(famille)
    end

    def brocante_d_agenda?(candidate)
      candidate.origin == "agenda_nancy" && candidate.full_text.to_s.match?(RUBRIQUE_BROCANTE)
    end

    # Seules les opportunités ont une catégorie : une belle histoire se suffit à elle-même.
    def categorie_pour(type, candidate, famille)
      return nil if type == "belle_histoire"
      return candidate.declic_category if SOURCES_CATEGORIE_FIXE.include?(candidate.origin) && candidate.declic_category.present?

      CATEGORIE_PAR_FAMILLE[famille] || candidate.declic_category.presence || "decouvrir"
    end

    # Garde-fou : une date plus d'un an avant la publication de la source est une année inventée
    # par le modèle (« 20.11 » lu comme 2024) ; on l'ignore plutôt que d'écarter à tort comme passé.
    def date_plausible(date, candidate)
      return date if date.nil? || candidate.published_on.nil?

      date < candidate.published_on - 365 ? nil : date
    end

    def parse_date(valeur)
      valeur.to_s.strip.empty? ? nil : Date.iso8601(valeur.to_s.strip)
    rescue Date::Error
      nil
    end
  end
end
