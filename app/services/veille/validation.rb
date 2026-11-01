# frozen_string_literal: true

module Veille
  # « Valider » : crée la fiche (Opportunity ou Story) à partir d'un candidat relu et
  # la met en ligne. C'est le seul chemin vers une fiche : aucun élément n'est publié
  # sans ce geste, ou sans la saisie de la commune d'un élément à localiser (voir
  # CandidatesController#completer). Un récit doit en plus être rédigé, sans point
  # bloquant, et avoir l'accord de la personne.
  #
  # Les fiches sont réécrites : résumé reformulé + lien « Pour en savoir plus »
  # vers l'origine ; ni texte ni photos de la source ne sont copiés.
  class Validation
    LIEN_TEXTE = "Pour en savoir plus"

    # Élément auquel il manque de quoi bâtir une fiche (commune, résumé reformulé).
    class Incomplet < StandardError; end

    def initialize(candidate)
      @c = candidate
    end

    # Rend la fiche créée, en ligne. Lève Incomplet ou ActiveRecord::RecordInvalid :
    # le candidat reste alors inchangé.
    def call
      raise Incomplet, "Cet élément a déjà sa fiche." if @c.publie?

      manques = []
      manques << "la commune" if @c.commune.blank?
      manques << "le résumé reformulé" if @c.summary.blank?
      raise Incomplet, "Il manque #{manques.to_sentence} : complète l'élément (ou écarte-le)." if manques.any?

      verifier_recit if @c.histoire?

      Candidate.transaction do
        fiche = @c.histoire? ? creer_histoire : creer_opportunite
        @c.update!(status: "publie")
        fiche
      end
    end

    private

    def verifier_recit
      raise Incomplet, "Le récit n'est pas encore rédigé : rédige-le et relis-le avant de le publier." if @c.draft_body.blank?
      raise Incomplet, "Le brouillon du récit a des points bloquants : corrige-les ou réécris-le." if @c.draft_status == "a_verifier"
      raise Incomplet, "L'accord de la personne n'est pas obtenu : la fiche ne peut pas être publiée." unless @c.accord_obtenu?
    end

    def creer_opportunite
      Opportunity.transaction do
        opp = Opportunity.create!(
          title: @c.title, description: description_opportunite, category: @c.declic_category.presence || "rencontres",
          location: @c.commune, city: @c.commune, starts_on: @c.starts_on, ends_on: @c.ends_on,
          schedule_text: @c.schedule_text, source: "veille", external_id: Digest::SHA1.hexdigest(@c.url),
          source_name: @c.source_label, source_url: @c.url, cta_button_text: LIEN_TEXTE, cta_button_url: @c.url,
          famille: (@c.famille if Opportunity::FAMILLES.key?(@c.famille)), is_active: true
        )
        @c.update!(opportunity: opp)
        @c.update_columns(full_text: nil, updated_at: Time.current) # même règle que pour les histoires
        opp
      end
    end

    def description_opportunite
      [@c.summary.presence || @c.excerpt, "#{LIEN_TEXTE} : #{@c.url}"].compact_blank.join("\n\n")
    end

    # Story#purge_veille_candidate_full_text efface le tampon à la création.
    def creer_histoire
      Story.create!(
        title: @c.title, chapo: @c.summary, body: @c.draft_body, location: @c.commune,
        happened_on: @c.published_on, source_url: @c.url,
        source_name: @c.source_label, source_published_on: @c.published_on, veille_candidate: @c,
        accord_obtenu_at: @c.accord_obtenu_at, is_active: true
      )
    end
  end
end
