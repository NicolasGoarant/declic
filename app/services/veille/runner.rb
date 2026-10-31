# frozen_string_literal: true

module Veille
  # Une exécution de la veille : collecte (connecteurs), stockage brut
  # (RawIngester), puis enrichissement IA plafonné. Appelé par les tâches
  # rake veille:quotidien (sources 1 à 5) et veille:hebdomadaire (presse).
  #
  # Rien n'est publié : tout aboutit dans la file de relecture /admin/veille.
  class Runner
    MAX_ENRICHIS = 30
    MAX_REDIGES  = 30
    # Au-delà, l'API est manifestement hors service (crédit épuisé, clé refusée,
    # panne) : inutile d'essuyer 30 refus et de remplir les logs.
    ERREURS_CONSECUTIVES_MAX = 3

    QUOTIDIEN   = [Connectors::Engagement, Connectors::AgendaNancy, Connectors::FormationLorraine,
                   Connectors::Transentreprise, Connectors::GazetteFrance].freeze
    HEBDOMADAIRE = [Connectors::Presse].freeze
    # Ordre de priorité du cahier des charges, pour répartir les 30 appels.
    PRIORITE = %w[jeveuxaider agenda_nancy formation transentreprise gazette presse].freeze

    Rapport = Struct.new(:sources, :crees, :doublons, :hors_zone, :passes, :enrichis, :ecartes, :erreurs_ia,
                         :cout_usd, :restants, :plafond, :rediges, :redaction_bloquee, :erreurs_redaction,
                         :a_rediger_restants, keyword_init: true)

    def initialize(connecteurs: QUOTIDIEN, ingester: RawIngester.new, enricher: nil, redacteur: nil,
                   max: MAX_ENRICHIS, max_rediges: MAX_REDIGES, logger: Rails.logger, http: nil)
      @http       = http
      @connecteurs = connecteurs
      @ingester   = ingester
      @enricher   = enricher
      @redacteur  = redacteur
      @max        = max
      @max_rediges = max_rediges
      @log        = logger
    end

    def run
      rapport = Rapport.new(sources: [], crees: 0, doublons: 0, hors_zone: 0, passes: 0,
                            enrichis: 0, ecartes: 0, erreurs_ia: 0, cout_usd: 0.0, restants: 0, plafond: false,
                            rediges: 0, redaction_bloquee: 0, erreurs_redaction: 0, a_rediger_restants: 0)
      collecter(rapport)
      enrichir(rapport)
      rediger(rapport)
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

      rapport.ecartes += 1 if candidat.ecarte?
    end

    # Étape séparée de l'enrichissement : un récit qui échoue (incident d'API) reste
    # « à reprendre » et repart à l'exécution suivante, sans refaire l'enrichissement.
    def rediger(rapport)
      return if rapport.plafond

      file = Veille::Candidate.a_rediger.order(:id).to_a
      rapport.a_rediger_restants = [file.size - @max_rediges, 0].max

      d_affilee = 0
      file.first(@max_rediges).each do |candidat|
        redacteur.draft(candidat)
        rapport.cout_usd += Cout.estimer(Redaction::Brouillon::MODEL, redacteur.usage)
        rapport.rediges += 1
        rapport.redaction_bloquee += 1 if candidat.draft_status == "a_verifier"
        d_affilee = 0
      rescue Veille::Plafond::Depasse => e
        @log.error("[Veille] rédaction arrêtée : #{e.message}")
        rapport.plafond = true
        break
      rescue AnthropicClient::AuthenticationError => e
        @log.error("[Veille] rédaction arrêtée : #{e.message}")
        rapport.erreurs_redaction += 1
        break
      rescue AnthropicClient::Error, AiPass::ParseError => e
        @log.warn("[Veille] rédaction ##{candidat.id} : #{e.class.name.demodulize} — #{e.message.slice(0, 150)}")
        rapport.erreurs_redaction += 1
        d_affilee += 1
        if d_affilee >= ERREURS_CONSECUTIVES_MAX
          @log.error("[Veille] rédaction arrêtée après #{d_affilee} erreurs d'affilée")
          break
        end
      end
    end

    def enricher = @enricher ||= AiEnricher.new
    def redacteur = @redacteur ||= Redaction::Brouillon.new

    def journaliser(r)
      etat = r.sources.map { |s| "#{s.nom}=#{s.statut}" }.join(" ")
      @log.info("[Veille] bilan — nouveaux #{r.crees}, doublons #{r.doublons}, hors zone #{r.hors_zone}, " \
                "passés #{r.passes}, enrichis #{r.enrichis}, écartés #{r.ecartes}, erreurs IA #{r.erreurs_ia}, " \
                "récits rédigés #{r.rediges} (dont #{r.redaction_bloquee} à vérifier), erreurs rédaction #{r.erreurs_redaction}, " \
                "en attente d'enrichissement #{r.restants}#{' · PLAFOND MENSUEL ATTEINT' if r.plafond} · coût estimé #{format('%.4f', r.cout_usd)} USD · #{etat}")
    end
  end
end
