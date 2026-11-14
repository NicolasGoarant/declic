# frozen_string_literal: true

module Veille
  # Date d'un événement telle que l'affiche la galerie : un jour, quelques jours, un créneau long avec sa
  # périodicité, ou une offre permanente. Pur : aucune base, aucune requête.
  #
  #   Creneau.pour(debut: 28 nov 2026)                      → « Sam. 28 nov. 2026 »
  #   Creneau.pour(debut: 27 nov, fin: 29 nov 2026)         → « Du 27 au 29 nov. 2026 »
  #   Creneau.pour(debut: 10 oct 2026, fin: 28 mars 2027,
  #                periodicite: "tous les samedis et dimanches", heure_debut: 11h, heure_fin: 12h)
  #                 → « Du 10 oct. 2026 au 28 mars 2027 » puis « tous les samedis et dimanches, 11h-12h »
  #   Creneau.pour()                                        → « Sans date limite » (ou « Toute l'année »)
  module Creneau
    Affichage = Struct.new(:date, :periodicite, keyword_init: true)

    TOUTE_L_ANNEE = /\A\s*(ouvert\s+)?toute l['’]ann[ée]e\.?\s*\z/i

    module_function

    def pour(debut: nil, fin: nil, heure_debut: nil, heure_fin: nil, periodicite: nil)
      periodicite = periodicite.to_s.squish.presence
      horaires = horaires(heure_debut, heure_fin)
      fin = nil if fin && debut && fin == debut

      return permanent(periodicite, horaires) if debut.nil? && fin.nil?

      if debut && fin.nil?
        Affichage.new(date: [ DatesFr.abregee(debut).upcase_first, horaires ].compact.join(" · "), periodicite: periodicite)
      elsif debut.nil?
        Affichage.new(date: "Jusqu'au #{jour_mois(fin, annee: true)}", periodicite: ligne(periodicite, horaires))
      else
        Affichage.new(date: plage(debut, fin), periodicite: ligne(periodicite, horaires))
      end
    end

    def permanent(periodicite, horaires)
      return Affichage.new(date: "Toute l'année", periodicite: ligne(nil, horaires)) if periodicite&.match?(TOUTE_L_ANNEE)

      Affichage.new(date: "Sans date limite", periodicite: ligne(periodicite, horaires))
    end

    # « Du 27 au 29 nov. 2026 », « Du 28 nov. au 13 déc. 2026 », « Du 10 oct. 2026 au 28 mars 2027 ».
    def plage(debut, fin)
      if debut.year == fin.year && debut.month == fin.month
        "Du #{DatesFr.jour(debut)} au #{jour_mois(fin, annee: true)}"
      elsif debut.year == fin.year
        "Du #{jour_mois(debut, annee: false)} au #{jour_mois(fin, annee: true)}"
      else
        "Du #{jour_mois(debut, annee: true)} au #{jour_mois(fin, annee: true)}"
      end
    end

    def jour_mois(date, annee:)
      [ DatesFr.jour(date), DatesFr::MOIS_ABREGES[date.month - 1], (date.year if annee) ].compact.join(" ")
    end

    # « 11h-12h », « 9h30 » ; nil sans heure de début (une heure de fin seule ne dit rien).
    def horaires(debut, fin)
      debut = Heure.lire(debut) or return nil
      fin = Heure.lire(fin)

      [ debut, (fin if fin && fin != debut) ].compact.map { |t| Heure.afficher(t) }.join("-")
    end

    # Périodicité puis horaires sur une ligne ; les horaires déjà dits dans la périodicité ne sont pas répétés.
    def ligne(periodicite, horaires)
      horaires = nil if periodicite&.match?(/\d\s?h/i)
      [ periodicite, horaires ].compact.join(", ").presence
    end
  end
end
