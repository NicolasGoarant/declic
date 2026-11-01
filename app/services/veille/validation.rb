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
      @point = point_precis

      Candidate.transaction do
        fiche = @c.histoire? ? creer_histoire : creer_opportunite
        @c.update!(status: "publie")
        fiche
      end
    end

    # La fiche telle qu'elle serait publiée, SANS rien enregistrer ni géocoder (pas d'appel Nominatim) :
    # mêmes attributs que `call`, donc même rendu dans les vues publiques. Position : l'adresse précise
    # si l'API Adresse la trouve ; sinon aucune (à la publication, le centre de la commune).
    # L'id 0 et le slug ne servent qu'à fabriquer les liens de la vue.
    def apercu
      @point = point_precis
      fiche = @c.histoire? ? Story.new(attributs_histoire.except(:veille_candidate)) : Opportunity.new(attributs_opportunite)
      fiche.id = 0
      fiche.created_at = fiche.updated_at = Time.current
      fiche.slug = fiche.title.to_s.parameterize.presence || "apercu"
      fiche.readonly!
      fiche
    end

    private

    # Le champ « Adresse » accepte une adresse postale (API Adresse) ou un nom de lieu comme « Musée des
    # Beaux-Arts » (OSM, que la BAN ne connaît pas). Rien trouvé : nil, donc la commune.
    def point_precis = AdresseBan.localiser(@c.adresse, @c.commune) || LieuOsm.localiser(@c.adresse, @c.commune)

    def verifier_recit
      raise Incomplet, "Le récit n'est pas encore rédigé : rédige-le et relis-le avant de le publier." if @c.draft_body.blank?
      raise Incomplet, "Le brouillon du récit a des points bloquants : corrige-les ou réécris-le." if @c.draft_status == "a_verifier"
      raise Incomplet, "L'accord de la personne n'est pas obtenu : la fiche ne peut pas être publiée." unless @c.accord_obtenu?
    end

    def attributs_opportunite
      {
        title: @c.title, description: description_opportunite, category: @c.declic_category.presence || "rencontres",
        **lieu, city: @c.commune, starts_on: @c.starts_on, ends_on: @c.ends_on,
        schedule_text: @c.schedule_text, source: "veille", external_id: Digest::SHA1.hexdigest(@c.url),
        source_name: @c.source_label, source_url: @c.url, cta_button_text: LIEN_TEXTE, cta_button_url: @c.url,
        famille: (@c.famille if Opportunity::FAMILLES.key?(@c.famille)), is_active: true
      }
    end

    def attributs_histoire
      {
        title: @c.title, chapo: @c.summary, body: @c.draft_body, **lieu,
        happened_on: @c.published_on, source_url: @c.url,
        source_name: @c.source_label, source_published_on: @c.published_on, veille_candidate: @c,
        accord_obtenu_at: @c.accord_obtenu_at, is_active: true
      }
    end

    def creer_opportunite
      Opportunity.transaction do
        opp = Opportunity.create!(attributs_opportunite)
        @c.update!(opportunity: opp)
        @c.update_columns(full_text: nil, updated_at: Time.current) # même règle que pour les histoires
        opp
      end
    end

    # Adresse précise trouvée : le repère va à l'adresse. Sinon (adresse vide, introuvable, API en
    # panne), la commune seule, géocodée par le modèle comme avant : la publication n'est jamais bloquée.
    def lieu
      return { location: @c.commune } if @point.nil?

      { location: "#{@c.adresse.squish}, #{@c.commune}", address: @c.adresse.squish,
        latitude: @point.latitude, longitude: @point.longitude }
    end

    def description_opportunite
      [@c.summary.presence || @c.excerpt, "#{LIEN_TEXTE} : #{@c.url}"].compact_blank.join("\n\n")
    end

    # Story#purge_veille_candidate_full_text efface le tampon à la création.
    def creer_histoire
      Story.create!(attributs_histoire)
    end
  end
end
