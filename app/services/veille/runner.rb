# frozen_string_literal: true

module Veille
  # Une exécution de la veille : collecte (connecteurs), stockage brut
  # (RawIngester), puis enrichissement IA plafonné. Appelé par les tâches
  # rake veille:quotidien (sources 1 à 5) et veille:hebdomadaire (presse).
  #
  # Rien n'est publié : tout aboutit dans la file de relecture /admin/veille.
  class Runner
    MAX_ENRICHIS = 30
    # Au-delà, l'API est manifestement hors service (crédit épuisé, clé refusée,
    # panne) : inutile d'essuyer 30 refus et de remplir les logs.
    ERREURS_CONSECUTIVES_MAX = 3

    QUOTIDIEN   = [Connectors::Engagement, Connectors::AgendaNancy, Connectors::FormationLorraine,
                   Connectors::Transentreprise, Connectors::GazetteFrance].freeze
    HEBDOMADAIRE = [Connectors::Presse].freeze
    # Ordre de priorité du cahier des charges, pour répartir les 30 appels.
    PRIORITE = %w[jeveuxaider agenda_nancy formation transentreprise gazette presse].freeze

    Rapport = Struct.new(:sources, :crees, :doublons, :hors_zone, :passes, :enrichis, :ecartes, :erreurs_ia,
                         :cout_usd, :restants, :plafond, keyword_init: true)

    def initialize(connecteurs: QUOTIDIEN, ingester: RawIngester.new, enricher: nil, drafter: nil,
                   max: MAX_ENRICHIS, logger: Rails.logger, http: nil)
      @http       = http
      @connecteurs = connecteurs
      @ingester   = ingester
      @enricher   = enricher
      @drafter    = drafter
      @max        = max
      @log        = logger
    end

    def run
      rapport = Rapport.new(sources: [], crees: 0, doublons: 0, hors_zone: 0, passes: 0,
                            enrichis: 0, ecartes: 0, erreurs_ia: 0, cout_usd: 0.0, restants: 0, plafond: false)
      collecter(rapport)
      enrichir(rapport)
      journaliser(rapport)
      rapport
    end

    private

    def collecter(rapport)
      http = @http || Veille::Http.new
      @connecteurs.each do |klasse|
        resultat = (klasse.is_a?(Class) ? klasse.new(http: http) : klasse).call
        rapport.sources << resultat
        bilan = @ingester.ingest(resultat.items)
        rapport.crees     += bilan.crees.size
        rapport.doublons  += bilan.doublons
        rapport.hors_zone += bilan.hors_zone
        rapport.passes    += bilan.passes
        @log.info("[Veille] #{resultat.nom} : #{resultat.statut} — #{resultat.message} (#{bilan.crees.size} nouveau(x))")
      end
    end

    def enrichir(rapport)
      file = Veille::Candidate.a_enrichir.to_a.sort_by do |c|
        [PRIORITE.index(c.origin) || PRIORITE.size, c.starts_on || Date.new(9999), c.id]
      end
      rapport.restants = [file.size - @max, 0].max

      d_affilee = 0
      file.first(@max).each do |candidat|
        enrichir_un(candidat, rapport)
        d_affilee = 0
      rescue Veille::Plafond::Depasse => e
        @log.error("[Veille] enrichissement arrêté : #{e.message}")
        rapport.plafond = true
        break
      rescue AnthropicClient::AuthenticationError => e
        @log.error("[Veille] enrichissement arrêté : #{e.message}")
        rapport.erreurs_ia += 1
        break
      rescue AnthropicClient::Error, AiPass::ParseError => e
        @log.warn("[Veille] enrichissement ##{candidat.id} : #{e.class.name.demodulize} — #{e.message.slice(0, 150)}")
        rapport.erreurs_ia += 1
        d_affilee += 1
        if d_affilee >= ERREURS_CONSECUTIVES_MAX
          @log.error("[Veille] enrichissement arrêté après #{d_affilee} erreurs d'affilée")
          break
        end
      end
    end

    def enrichir_un(candidat, rapport)
      enricher.enrich(candidat)
      rapport.cout_usd += Cout.estimer(AiEnricher::MODEL, enricher.usage)
      rapport.enrichis += 1

      if candidat.ecarte?
        rapport.ecartes += 1
      elsif candidat.item_type == "belle_histoire" && candidat.summary.present?
        drafter.draft(candidat)
        rapport.cout_usd += Cout.estimer(StoryDrafter::MODEL, drafter.usage)
      end
    end

    def enricher = @enricher ||= AiEnricher.new
    def drafter  = @drafter  ||= StoryDrafter.new

    def journaliser(r)
      etat = r.sources.map { |s| "#{s.nom}=#{s.statut}" }.join(" ")
      @log.info("[Veille] bilan — nouveaux #{r.crees}, doublons #{r.doublons}, hors zone #{r.hors_zone}, " \
                "passés #{r.passes}, enrichis #{r.enrichis}, écartés #{r.ecartes}, erreurs IA #{r.erreurs_ia}, " \
                "en attente d'enrichissement #{r.restants}#{' · PLAFOND MENSUEL ATTEINT' if r.plafond} · coût estimé #{format('%.4f', r.cout_usd)} USD · #{etat}")
    end
  end
end
