# frozen_string_literal: true

module Veille
  # Budget mensuel de l'API Anthropic, mesuré sur le journal (Veille::AppelIa).
  # Vérifié avant chaque appel : une fois atteint, plus aucun appel ne part
  # jusqu'au mois suivant. Réglable par VEILLE_BUDGET_USD_MOIS (15 $ par défaut).
  module Plafond
    DEFAUT_USD = 15.0

    # Plafond atteint : rien n'a été envoyé à l'API.
    class Depasse < StandardError; end

    module_function

    def budget
      Float(ENV.fetch("VEILLE_BUDGET_USD_MOIS", DEFAUT_USD), exception: false)&.then { |v| v.positive? ? v : nil } || DEFAUT_USD
    end

    def depense(jour = Date.current) = Veille::AppelIa.cout_du_mois(jour)

    def atteint?(jour = Date.current) = depense(jour) >= budget

    def verifier!(jour = Date.current)
      return unless atteint?(jour)

      raise Depasse, format("Plafond mensuel atteint : %.2f $ dépensés sur %.2f $ (VEILLE_BUDGET_USD_MOIS).", depense(jour), budget)
    end
  end
end
