# frozen_string_literal: true

module Veille
  # Point unique de journalisation des appels à l'API Anthropic : toute écriture dans
  # veille_appels_ia passe ici (modèle, jetons, coût estimé, origine). Le plafond mensuel
  # (Veille::Plafond) lit ce journal ; un appel hors journal échappe donc au plafond.
  #
  # `origine` : qui appelle (« veille » pour le tri et la rédaction, « banc_essai », « ai_ping »…).
  module JournalIa
    ORIGINE_DEFAUT = "veille"

    module_function

    def enregistrer(passe:, modele:, statut:, usage: nil, origine: ORIGINE_DEFAUT, candidate: nil, erreur: nil, duree_ms: nil, cout_usd: nil, cree_le: nil)
      Veille::AppelIa.create!(
        {
          candidate: candidate, passe: passe, modele: modele, statut: statut, origine: origine,
          input_tokens: usage.to_h["input_tokens"].to_i, output_tokens: usage.to_h["output_tokens"].to_i,
          cout_usd: cout_usd || Veille::Cout.estimer(modele, usage), erreur: erreur, duree_ms: duree_ms
        }.merge(cree_le ? { created_at: cree_le } : {})
      )
    end

    # Mesure un appel (bloc rendant la réponse Anthropic) et le journalise, y compris en cas d'erreur.
    # Le plafond est vérifié avant l'envoi.
    def appeler(passe:, modele:, origine:, candidate: nil)
      debut = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      duree = -> { ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - debut) * 1000).round }
      begin
        Veille::Plafond.verifier!
      rescue Veille::Plafond::Depasse => e
        enregistrer(passe: passe, modele: modele, statut: "plafond", origine: origine, candidate: candidate, erreur: e.message, duree_ms: duree.call)
        raise
      end
      begin
        reponse = yield
      rescue AnthropicClient::Error => e
        enregistrer(passe: passe, modele: modele, statut: "erreur_api", origine: origine, candidate: candidate,
                    erreur: "#{e.class.name.demodulize} : #{e.message.slice(0, 300)}", duree_ms: duree.call)
        raise
      end
      enregistrer(passe: passe, modele: modele, statut: "ok", usage: reponse["usage"], origine: origine, candidate: candidate, duree_ms: duree.call)
      reponse
    end
  end
end
