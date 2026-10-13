# frozen_string_literal: true

module Veille
  # « Valider » : crée le brouillon (Opportunity ou Story, jamais actif) à partir
  # d'un candidat relu. C'est le seul chemin vers une fiche : aucun élément n'est
  # publié sans ce clic, et le brouillon reste inactif jusqu'à sa mise en ligne
  # depuis l'admin des fiches.
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

    # Rend la fiche créée. Lève Incomplet ou ActiveRecord::RecordInvalid :
    # le candidat reste alors inchangé.
    def call
      manques = []
      manques << "la commune" if @c.commune.blank?
      manques << "le résumé reformulé" if @c.summary.blank?
      raise Incomplet, "Il manque #{manques.to_sentence} : complète l'élément (ou écarte-le)." if manques.any?

      fiche = @c.histoire? ? creer_histoire : creer_opportunite
      @c.update!(status: "publie")
      fiche
    end

    private

    def creer_opportunite
      Opportunity.transaction do
        opp = Opportunity.create!(
          title: @c.title, description: description_opportunite, category: @c.declic_category.presence || "rencontres",
          location: @c.commune, city: @c.commune, starts_on: @c.starts_on, ends_on: @c.ends_on,
          schedule_text: @c.schedule_text, source: "veille", external_id: Digest::SHA1.hexdigest(@c.url),
          source_name: @c.source_label, source_url: @c.url, cta_button_text: LIEN_TEXTE, cta_button_url: @c.url,
          is_active: false
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
      corps = @c.draft_body.presence ||
              StoryDrafter.finaliser(@c.summary.to_s, source_label: @c.source_label, url: @c.url)
      Story.create!(
        title: @c.title, chapo: @c.summary, body: corps, location: @c.commune, tags: tag_categorie,
        thematique: @c.declic_category, happened_on: @c.published_on, source_url: @c.url,
        source_name: @c.source_label, source_published_on: @c.published_on, veille_candidate: @c
      )
    end

    def tag_categorie = Categorie.trouver(@c.declic_category)&.libelle
  end
end
