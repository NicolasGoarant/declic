# frozen_string_literal: true

module Veille
  # Une exécution de la veille : collecte (connecteurs), stockage brut
  # (RawIngester), puis enrichissement IA plafonné. Appelé par les tâches
  # rake veille:quotidien. La presse n'y figure pas : voir Connectors::Presse.
  #
  # Rien n'est publié : tout aboutit dans la file de relecture /admin/veille.
  class Runner
    MAX_ENRICHIS = 30
    MAX_REDIGES  = 30
    # Au-delà, l'API est manifestement hors service (crédit épuisé, clé refusée,
    # panne) : inutile d'essuyer 30 refus et de remplir les logs.
    ERREURS_CONSECUTIVES_MAX = 3

    # Transentreprise retiré le 03/11/2026 : ses mentions légales interdisent, sans autorisation écrite, la
    # collecte automatisée des annonces et la réutilisation de ses flux RSS (rapports/veille-entreprendre-2026-11-03.md).
    # Connecteur conservé, non lancé, comme la Gazette et JeVeuxAider.
    QUOTIDIEN   = [Connectors::AgendaNancy, Connectors::Communes, Connectors::FluxPresse].freeze
    # Interrupteur de la presse (ICI Lorraine, France 3 Nancy) dans le job quotidien : éteint tant que
    # ENV["VEILLE_PRESSE_ACTIVE"] n'est pas « true » (ou 1, oui, on).
    PRESSE_VALEURS_ON = %w[true 1 oui yes on].freeze

    def self.presse_active? = PRESSE_VALEURS_ON.include?(ENV["VEILLE_PRESSE_ACTIVE"].to_s.strip.downcase)

    # Connecteurs du job quotidien selon l'interrupteur.
    def self.quotidien = presse_active? ? QUOTIDIEN : QUOTIDIEN - [Connectors::FluxPresse]
    # Ordre de priorité du cahier des charges, pour répartir les 30 appels.
    PRIORITE = %w[agenda_nancy communes ici_lorraine france3_lorraine].freeze

    Rapport = Struct.new(:sources, :crees, :doublons, :hors_zone, :passes, :enrichis, :ecartes, :erreurs_ia,
                         :cout_usd, :restants, :plafond, :rediges, :redaction_bloquee, :erreurs_redaction,
                         :a_rediger_restants, :tokens, :prefiltre, keyword_init: true)

    def initialize(connecteurs: self.class.quotidien, ingester: RawIngester.new, enricher: nil, redacteur: nil,
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
                            rediges: 0, redaction_bloquee: 0, erreurs_redaction: 0, a_rediger_restants: 0, tokens: {},
                            prefiltre: Prefiltre::Bilan.vide)
      @depart_journal = Veille::AppelIa.maximum(:id).to_i
      collecter(rapport)
      enrichir(rapport)
      rediger(rapport)
      journaliser(rapport)
      rapport
    end

    # Rattrapage : rédige les récits en attente (belles histoires déjà enrichies) sans rien collecter
    # ni enrichir. Mêmes plafonds et mêmes arrêts que l'exécution normale.
    def rattraper_redactions
      rapport = Rapport.new(sources: [], crees: 0, doublons: 0, hors_zone: 0, passes: 0,
                            enrichis: 0, ecartes: 0, erreurs_ia: 0, cout_usd: 0.0, restants: 0, plafond: false,
                            rediges: 0, redaction_bloquee: 0, erreurs_redaction: 0, a_rediger_restants: 0, tokens: {},
                            prefiltre: Prefiltre::Bilan.vide)
      @depart_journal = Veille::AppelIa.maximum(:id).to_i
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
        bilan = @ingester.ingest(prefiltrer(resultat.items, rapport))
        rapport.crees     += bilan.crees.size
        rapport.doublons  += bilan.doublons
        rapport.hors_zone += bilan.hors_zone
        rapport.passes    += bilan.passes
        @log.info("[Veille] #{resultat.nom} : #{resultat.statut} — #{resultat.message} (#{bilan.crees.size} nouveau(x))")
      end
    end

    # Préfiltre en code (Veille::Prefiltre) des seuls flux de presse : ce qui ne touche ni le territoire ni un
    # thème Déclic, ou relève d'une exclusion (sport, faits divers…), n'est même pas stocké, donc jamais envoyé à l'IA.
    def prefiltrer(items, rapport)
      presse, autres = Array(items).partition { |i| Candidate::ORIGINES_FLUX_PRESSE.include?(i.origin) }
      return items if presse.empty?

      bilan = Prefiltre.filtrer(presse)
      rapport.prefiltre.recus += bilan.recus
      rapport.prefiltre.retenus.concat(bilan.retenus)
      rapport.prefiltre.ecartes += bilan.ecartes
      bilan.motifs.each { |motif, n| rapport.prefiltre.motifs[motif] += n }
      autres + bilan.retenus
    end

    def enrichir(rapport)
      file = Veille::Candidate.a_enrichir.to_a
      file.reject! { |c| Candidate::ORIGINES_FLUX_PRESSE.include?(c.origin) } unless self.class.presse_active?
      file = file.sort_by do |c|
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

    # Jetons et coût de CETTE exécution, lus dans le journal des appels (premier passage, escalade et
    # rédaction compris, y compris les appels en erreur), par modèle.
    def mesurer(r)
      appels = Veille::AppelIa.where("id > ?", @depart_journal.to_i)
      r.tokens = appels.group(:modele).pluck(:modele, Arel.sql("COUNT(*)"), Arel.sql("SUM(input_tokens)"), Arel.sql("SUM(output_tokens)"))
                       .to_h { |m, n, i, o| [m, { appels: n, entree: i.to_i, sortie: o.to_i }] }
      r.cout_usd = appels.sum(:cout_usd).to_f
    end

    def journaliser(r)
      mesurer(r)
      jetons = r.tokens.map { |m, t| "#{m}=#{t[:appels]} appel(s) #{t[:entree]} entrée / #{t[:sortie]} sortie" }.join(" ; ")
      etat = r.sources.map { |s| "#{s.nom}=#{s.statut}" }.join(" ")
      pf = r.prefiltre
      @log.info("[Veille] préfiltre presse — reçus #{pf.recus}, retenus #{pf.retenus.size}, écartés #{pf.ecartes}" \
                "#{" (#{pf.motifs.map { |m, n| "#{m} : #{n}" }.join(', ')})" if pf.ecartes.positive?}")
      @log.info("[Veille] bilan — nouveaux #{r.crees}, doublons #{r.doublons}, hors zone #{r.hors_zone}, " \
                "passés #{r.passes}, enrichis #{r.enrichis}, écartés #{r.ecartes}, erreurs IA #{r.erreurs_ia}, " \
                "récits rédigés #{r.rediges} (dont #{r.redaction_bloquee} à vérifier), erreurs rédaction #{r.erreurs_redaction}, " \
                "en attente d'enrichissement #{r.restants}#{' · PLAFOND MENSUEL ATTEINT' if r.plafond} · coût estimé #{format('%.4f', r.cout_usd)} USD · jetons : #{jetons.presence || 'aucun'} · #{etat}")
    end
  end
end
