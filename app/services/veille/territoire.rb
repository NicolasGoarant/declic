# frozen_string_literal: true

module Veille
  # Périmètre géographique de la veille : une belle histoire peut venir de tout
  # le Grand Est, une opportunité doit se trouver en Meurthe-et-Moselle (il faut
  # pouvoir s'y rendre). Les 5 115 communes viennent de geo.api.gouv.fr (région 44).
  #
  # Le repérage se fait aussi dans le code, pas seulement par l'IA : le prompt
  # d'AiEnricher lui demande une commune vide hors du Grand Nancy.
  module Territoire
    MEURTHE_ET_MOSELLE = "54"
    FICHIER = Rails.root.join("config/veille/communes_grand_est.json")

    # Communes dont le nom est aussi un mot courant, un prénom ou un nom de famille :
    # reconnues si la source ou le modèle les donne, jamais repérées dans un texte libre.
    AMBIGUS = [
      "aire", "annelles", "arches", "aube", "auge", "autruche", "avril", "bannes", "barbas", "baye", "bergeres",
      "bonnet", "boulange", "bourg", "bourguignons", "broyes", "bru", "bure", "cesse", "chatres", "cheminot",
      "chenevieres", "cramant", "cuis", "cuves", "doux", "eclaires", "ecueil", "falaise", "faux", "feves", "fontaine",
      "fosse", "germaine", "germaines", "giraumont", "glaire", "grand", "grenant", "gueux", "hans", "housseras",
      "jalons", "jury", "lamarche", "lancon", "lemmes", "lentilles", "ley", "lucy", "lumes", "lusse", "lutter",
      "magenta", "magnant", "many", "marre", "meures", "mey", "mouron", "mousson", "moyen", "norrois", "noyers",
      "orges", "ormes", "ornes", "pannes", "pauvres", "plaine", "pleurs", "poissons", "poivres", "poix", "pouilly",
      "pure", "racines", "rances", "raves", "reveillon", "riche", "romain", "russ", "saint bernard", "saint pierre",
      "salon", "sand", "secourt", "selles", "serres", "seuil", "sommeilles", "son", "soude", "soyers", "suisse", "sy",
      "tendon", "this", "tiercelet", "toges", "tournes", "vaillant", "vaudeville", "vaux", "verrieres", "vignot",
      "ville", "viviers", "voisines", "voue", "voyer",
      "la baffe", "la besace", "la chaise", "la chapelle", "la forestiere", "la forge", "la noue", "la salle", "la
      veuve", "le bonhomme", "le buisson", "le chemin", "le chene", "le mont", "le roulier", "le syndicat", "les
      croutes", "les etangs", "les forges", "les granges", "les loges", "les thons"
    ].to_set.freeze

    MAX_MOTS = 7 # « Saint-Rémy-en-Bouzemont-Saint-Genest-et-Isson »

    module_function

    # Nom officiel si `nom` est une commune du Grand Est (casse, accents, tirets ignorés).
    def canonique(nom)
      Veille::GrandNancy.canonique(nom) || communes[cle(nom)]&.first
    end

    def grand_est?(nom) = canonique(nom).present?

    def meurthe_et_moselle?(nom)
      Veille::GrandNancy.inclut?(nom) || communes[cle(nom)]&.last.to_a.include?(MEURTHE_ET_MOSELLE)
    end

    # La commune est-elle dans le périmètre de ce type de contenu ? Sans type
    # (presse, gazette : l'IA tranchera), le périmètre le plus large s'applique.
    def admis?(nom, type)
      type.to_s == "opportunite" ? meurthe_et_moselle?(nom) : grand_est?(nom)
    end

    # Première commune du Grand Est citée dans un texte libre, sinon nil. Le nom doit
    # commencer par une majuscule. À une même position, le nom le plus long l'emporte,
    # pour que « Villers-lès-Nancy » ne soit pas lu « Villers ».
    def trouver_dans(texte)
      texte = texte.to_s
      mots = texte.to_enum(:scan, /[[:alnum:]]+/).map { Regexp.last_match }
      mots.each_index do |i|
        next unless mots[i][0].match?(/\A[[:upper:]]/)

        MAX_MOTS.downto(1) do |n|
          next if i + n > mots.size
          next if texte[mots[i + n - 1].end(0)] == "-" # « Dampierre-sur-Salon » n'est pas Dampierre

          trouve = reperer(Veille::Text.normalize(mots[i, n].map { |m| m[0] }.join(" ")))
          return trouve if trouve
        end
      end
      nil
    end

    def reperer(cle)
      return nil if AMBIGUS.include?(cle)

      Veille::GrandNancy::PAR_CLE[cle] || communes[cle]&.first
    end
    private_class_method :reperer

    def cle(nom) = Veille::Text.normalize(nom).sub(/\A(ville de|commune de)\s+/, "")
    private_class_method :cle

    # { "pont a mousson" => ["Pont-à-Mousson", ["54"]] }
    def communes
      @communes ||= JSON.parse(File.read(FICHIER)).to_h { |nom, deps| [Veille::Text.normalize(nom), [nom, deps]] }
    end
    private_class_method :communes
  end
end
