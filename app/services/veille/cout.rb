# frozen_string_literal: true

module Veille
  # Estimation du coût des appels Anthropic, pour les logs. Tarifs en dollars par
  # million de tokens (entrée, sortie) : Haiku 4.5 = 1 / 5 ; les modèles Sonnet
  # sont comptés à 3 / 15, estimation prudente à revoir si la grille change.
  module Cout
    TARIFS = { "haiku" => [1.0, 5.0], "sonnet" => [3.0, 15.0] }.freeze

    Etat = Struct.new(:mois, :depense, :budget, :appels, :par_passe, :par_statut, :par_modele, keyword_init: true) do
      def reste = [budget - depense, 0.0].max
      def atteint? = depense >= budget
    end

    module_function

    # Dépense d'un mois civil d'après le journal (Veille::AppelIa), comparée au plafond.
    def etat_du_mois(jour = Date.current)
      appels = Veille::AppelIa.du_mois(jour)
      groupe = ->(colonne) { appels.group(colonne).pluck(colonne, Arel.sql("COUNT(*)"), Arel.sql("SUM(cout_usd)")).to_h { |k, n, c| [k, { appels: n, cout: c.to_f }] } }
      Etat.new(mois: jour.beginning_of_month, depense: appels.sum(:cout_usd).to_f, budget: Veille::Plafond.budget, appels: appels.count,
               par_passe: groupe.(:passe), par_statut: groupe.(:statut), par_modele: groupe.(:modele))
    end

    def estimer(modele, usage)
      return 0.0 if usage.blank?

      entree, sortie = TARIFS.find { |k, _| modele.to_s.include?(k) }&.last || TARIFS["sonnet"]
      ((usage["input_tokens"].to_i * entree) + (usage["output_tokens"].to_i * sortie)) / 1_000_000.0
    end
  end
end
