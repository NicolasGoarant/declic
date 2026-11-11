# frozen_string_literal: true

require "csv"

module Veille
  # Banc d'essai : trie les mêmes éléments avec deux modèles, séparément, et exporte un CSV comparatif
  # (type et score de chacun, jetons et coût de chaque appel, colonne vide « avis de Nicolas »).
  # N'écrit rien en base, ne publie rien : les appels passent directement par AnthropicClient.
  #
  # Les éléments viennent des candidats déjà en base (Veille::Candidate), jamais d'un flux lu pour l'occasion.
  # Les origines dont les CGU s'opposent à la fouille de textes et à l'IA (Veille::AnnuairePresse.ecartees)
  # sont refusées, sauf autorisation écrite déclarée (autorisation: true).
  class BancEssai
    class OrigineInterdite < StandardError; end

    COLONNES = ["titre", "lien", "origine", "type Haiku", "score Haiku", "jetons Haiku (entrée/sortie)", "coût Haiku ($)",
                "type Sonnet", "score Sonnet", "jetons Sonnet (entrée/sortie)", "coût Sonnet ($)", "accord", "avis de Nicolas"].freeze

    Ligne = Struct.new(:candidat, :a, :b, keyword_init: true)
    Essai = Struct.new(:type, :score, :entree, :sortie, :cout, :erreur, keyword_init: true)

    attr_reader :modele_a, :modele_b

    def initialize(modele_a: "claude-haiku-5-5", modele_b: "claude-sonnet-5-5", client: nil, today: Date.current)
      @modele_a, @modele_b, @client, @today = modele_a, modele_b, client, today
    end

    # `par_origine` : { "agenda_nancy" => 20, "communes" => 20 }. Préfiltre appliqué quand c'est possible
    # (on prend d'abord les éléments retenus, puis on complète avec les autres).
    def choisir(par_origine, autorisation: false)
      interdites = Veille::AnnuairePresse.ecartees.map(&:origine) + Veille::AnnuairePresse.automatisables.map(&:origine)
      par_origine.flat_map do |origine, n|
        if interdites.include?(origine) && !autorisation
          raise OrigineInterdite, "#{origine} : CGU opposées à la fouille de textes et à l'IA, aucune autorisation écrite déclarée."
        end

        next histoires(n) if origine == "stories"

        tous = Veille::Candidate.where(origin: origine).order(:id).to_a
        retenus, autres = tous.partition { |c| Veille::Prefiltre.evaluer(titre: c.title, texte: c.full_text.presence || c.excerpt).retenu? }
        (retenus + autres).first(n)
      end
    end

    # Belles Histoires déjà publiées (textes de Nicolas) : le type attendu est « belle_histoire ».
    FauxCandidat = Struct.new(:title, :url, :origin, :full_text, :excerpt, :commune, :starts_on, :ends_on, :schedule_text, :published_on, keyword_init: true)

    def histoires(n)
      Story.where(is_active: true).order(:id).limit(n).map do |s|
        FauxCandidat.new(title: s.title, url: s.source_url, origin: "stories", full_text: [s.chapo, s.body.to_s].join("\n\n"), excerpt: s.chapo, commune: s.city)
      end
    end

    def run(candidats)
      candidats.map { |c| Ligne.new(candidat: c, a: trier(c, modele_a), b: trier(c, modele_b)) }
    end

    def trier(candidat, modele)
      params = Veille::AiEnricher.prompt_for(
        title: candidat.title, text: candidat.full_text.presence || candidat.excerpt, origin: candidat.origin, commune: candidat.commune,
        starts_on: candidat.starts_on, ends_on: candidat.ends_on, schedule_text: candidat.schedule_text,
        published_on: candidat.published_on, today: @today
      )
      reponse = client(modele).messages(**Veille::AiEnricher.params_pour(modele, params), model: modele)
      res = Veille::AiPass.parse_response(AnthropicClient.extract_text(reponse))
      usage = reponse["usage"]
      type = res["hors_ligne"] || res["famille"] == Veille::AiEnricher::HORS_LIGNE ? "hors ligne" : res["type"]
      Essai.new(type: type, score: res["confiance"].to_i.clamp(0, 100), entree: usage["input_tokens"].to_i,
                sortie: usage["output_tokens"].to_i, cout: Veille::Cout.estimer(modele, usage))
    rescue AnthropicClient::AuthenticationError
      raise
    rescue AnthropicClient::Error, Veille::AiPass::ParseError => e
      Essai.new(erreur: "#{e.class.name.demodulize} : #{e.message.slice(0, 120)}", entree: 0, sortie: 0, cout: 0.0)
    end

    # Accord : même type (opportunité / belle histoire / hors ligne).
    def self.accord?(ligne) = ligne.a.type.present? && ligne.a.type == ligne.b.type

    def self.resume(lignes)
      valides = lignes.select { |l| l.a.type && l.b.type }
      n = [lignes.size, 1].max
      v = [valides.size, 1].max
      {
        elements: lignes.size, compares: valides.size,
        accord_pct: (100.0 * valides.count { |l| accord?(l) } / v).round(1),
        ecart_score_moyen: (valides.sum { |l| (l.a.score - l.b.score).abs }.to_f / v).round(1),
        cout_a_100: (100.0 * lignes.sum { |l| l.a.cout } / n).round(4),
        cout_b_100: (100.0 * lignes.sum { |l| l.b.cout } / n).round(4)
      }
    end

    def self.csv(lignes)
      CSV.generate do |csv|
        csv << COLONNES
        lignes.each do |l|
          cellule = ->(e) { [e.type || e.erreur, e.score, "#{e.entree}/#{e.sortie}", format("%.5f", e.cout)] }
          csv << [l.candidat.title, l.candidat.url, l.candidat.origin, *cellule.(l.a), *cellule.(l.b), accord?(l) ? "oui" : "non", ""]
        end
      end
    end

    private

    def client(modele)
      return @client if @client

      (@clients ||= {})[modele] ||= AnthropicClient.new(model: modele, timeout: 60, open_timeout: 5, retries: 1)
    end
  end
end
