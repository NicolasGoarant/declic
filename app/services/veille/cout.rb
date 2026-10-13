# frozen_string_literal: true

module Veille
  # Estimation du coût des appels Anthropic, pour les logs. Tarifs en dollars par
  # million de tokens (entrée, sortie) : Haiku 4.5 = 1 / 5 ; les modèles Sonnet
  # sont comptés à 3 / 15, estimation prudente à revoir si la grille change.
  module Cout
    TARIFS = { "haiku" => [1.0, 5.0], "sonnet" => [3.0, 15.0] }.freeze

    module_function

    def estimer(modele, usage)
      return 0.0 if usage.blank?

      entree, sortie = TARIFS.find { |k, _| modele.to_s.include?(k) }&.last || TARIFS["sonnet"]
      ((usage["input_tokens"].to_i * entree) + (usage["output_tokens"].to_i * sortie)) / 1_000_000.0
    end
  end
end
