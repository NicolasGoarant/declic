# frozen_string_literal: true

# Galerie d'administration : Belles Histoires et Opportunités en ligne, et candidats proposés par la veille,
# vus ensemble. Lecture seule : aucune règle de publication ici, les actions (Valider, Écarter…) restent celles
# de Admin::Veille::CandidatesController. Pas de migration : tout est dérivé des statuts existants.
#
# Statuts affichés :
#   en_ligne   fiche publique (Story active ; Opportunity de Opportunity.publiques)
#   retire     fiche existante mais hors du site (désactivée, ou terminée)
#   propose    candidat classé par l'IA, à valider (pending enrichi, ou retenu)
#   a_verifier candidat marqué « à vérifier »
#   non_trie   candidat pas encore passé par l'IA
#   ecarte     candidat écarté (visible seulement via le filtre)
# Les candidats « publie » ne sont pas listés : leur fiche l'est déjà.
class Galerie
  # « À relire » : préréglage (proposé + à vérifier), l'ancienne file de relecture.
  A_RELIRE = %w[propose a_verifier].freeze
  STATUTS = {
    "a_relire" => "À relire (proposé + à vérifier)", "en_ligne" => "En ligne", "propose" => "Proposé (à valider)", "a_verifier" => "À vérifier",
    "non_trie" => "Non trié", "retire" => "Retirée du site", "ecarte" => "Écarté"
  }.freeze
  TYPES   = { "opportunite" => "Opportunité", "belle_histoire" => "Belle Histoire" }.freeze
  PAR_PAGE = 48

  Carte = Struct.new(:cle, :type, :statut, :record, :titre, :resume, :categorie, :commune, :date, :source, :score, :cree_le, :cle_categorie,
                     :raison, :fiabilite, :a_localiser, :famille, :recit, :collecte_le, keyword_init: true) do
    def candidat? = record.is_a?(Veille::Candidate)
    def histoire? = type == "belle_histoire"
  end

  Filtres = Struct.new(:type, :statut, :categorie, :commune, :source, :q, :tri, :page, :depuis, :a_localiser, keyword_init: true)

  attr_reader :filtres

  def initialize(params = {})
    p = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    p = p.with_indifferent_access
    @filtres = Filtres.new(
      type: p[:type].presence_in(TYPES.keys), statut: p[:statut].presence_in(STATUTS.keys),
      categorie: p[:categorie].presence, commune: p[:commune].presence, source: p[:source].presence,
      q: p[:q].to_s.strip.presence, tri: p[:tri] == "score" ? "score" : "date", page: [p[:page].to_i, 1].max,
      depuis: (Date.iso8601(p[:depuis].to_s) rescue nil), a_localiser: p[:a_localiser].present? ? "1" : nil
    )
  end

  def cartes_brutes
    @cartes_brutes ||= opportunites + histoires + candidats
  end

  # Compteurs de tête : indépendants des filtres, par statut et par type.
  def compteurs
    @compteurs ||= begin
      comptes = Hash.new(0)
      cartes_brutes.each do |c|
        comptes[[c.statut, c.type]] += 1
        comptes[["a_relire", c.type]] += 1 if A_RELIRE.include?(c.statut)
      end
      STATUTS.keys.index_with do |statut|
        { total: TYPES.keys.sum { |t| comptes[[statut, t]] } + comptes[[statut, nil]],
          "opportunite" => comptes[[statut, "opportunite"]], "belle_histoire" => comptes[[statut, "belle_histoire"]] }
      end
    end
  end

  def cartes
    @cartes ||= trier(filtrer(cartes_brutes))
  end

  def total = cartes.size
  def pages = [(total.to_f / PAR_PAGE).ceil, 1].max
  def page = [filtres.page, pages].min
  def page_cartes = cartes.slice((page - 1) * PAR_PAGE, PAR_PAGE) || []

  # Page (dans la sélection filtrée) où se trouve une carte ; nil si elle n'y figure pas.
  def page_de(cle)
    i = cartes.index { |c| c.cle == cle }
    i && (i / PAR_PAGE) + 1
  end

  # Valeurs proposées par les filtres (sur l'ensemble, pas sur la sélection).
  def categories = cartes_brutes.filter_map(&:categorie).uniq.sort
  def communes   = cartes_brutes.filter_map(&:commune).uniq.sort_by { |c| I18n.transliterate(c).downcase }
  def sources    = cartes_brutes.filter_map(&:source).uniq.sort_by(&:downcase)

  private

  def filtrer(cartes)
    f = filtres
    cartes = cartes.select do |c|
      if f.statut == "a_relire" then A_RELIRE.include?(c.statut)
      elsif f.statut then c.statut == f.statut
      else c.statut != "ecarte"
      end
    end
    cartes = cartes.select { |c| c.collecte_le && c.collecte_le.to_date >= f.depuis } if f.depuis
    cartes = cartes.select(&:a_localiser) if f.a_localiser
    cartes = cartes.select { |c| c.type == f.type } if f.type
    cartes = cartes.select { |c| c.categorie == f.categorie } if f.categorie
    cartes = cartes.select { |c| c.commune == f.commune } if f.commune
    cartes = cartes.select { |c| c.source == f.source } if f.source
    if f.q
      mot = normaliser(f.q)
      cartes = cartes.select { |c| normaliser("#{c.titre} #{c.resume}").include?(mot) }
    end
    cartes
  end

  # Plus récent d'abord (date d'ajout) ; par score : les candidats les mieux notés d'abord, les fiches sans score à la fin.
  def trier(cartes)
    if filtres.tri == "score"
      cartes.sort_by { |c| [c.score ? 0 : 1, -c.score.to_i, -c.cree_le.to_i] }
    else
      cartes.sort_by { |c| -c.cree_le.to_i }
    end
  end

  def normaliser(texte) = I18n.transliterate(texte.to_s).downcase

  def opportunites
    publiques = Opportunity.publiques.pluck(:id).to_set
    Opportunity.all.map do |o|
      Carte.new(cle: "opportunity_#{o.id}", type: "opportunite", statut: publiques.include?(o.id) ? "en_ligne" : "retire", record: o,
                titre: o.title, resume: o.description, categorie: Categorie.trouver(o.category)&.libelle, commune: o.city.presence,
                date: o.date_debut, source: o.source.presence, score: nil, cree_le: o.created_at, cle_categorie: o.category, collecte_le: o.created_at)
    end
  end

  def histoires
    Story.all.map do |s|
      Carte.new(cle: "story_#{s.id}", type: "belle_histoire", statut: s.is_active ? "en_ligne" : "retire", record: s,
                titre: s.title, resume: s.chapo, categorie: nil, commune: s.city.presence,
                date: s.happened_on || s.source_published_on, source: s.source_name.presence, score: nil, cree_le: s.created_at, cle_categorie: Categorie::HISTOIRES, collecte_le: s.created_at)
    end
  end

  def candidats
    Veille::Candidate.where.not(status: "publie").includes(:source).map do |c|
      Carte.new(cle: "candidate_#{c.id}", type: c.item_type.presence, statut: statut_candidat(c), record: c,
                titre: c.title.presence || "(sans titre)", resume: c.summary.presence || c.excerpt, categorie: (c.histoire? ? nil : c.categorie_label),
                commune: c.commune.presence, date: c.starts_on || c.published_on, source: c.source_label, score: c.score, cree_le: c.created_at,
                cle_categorie: (c.histoire? ? Categorie::HISTOIRES : c.declic_category.presence),
                raison: c.reason.presence, fiabilite: c.reliability || "basse", a_localiser: c.a_localiser?,
                famille: (Opportunity::FAMILLES.fetch(c.famille, c.famille.to_s.humanize) if c.famille.present?),
                recit: (c.draft_status if c.histoire? && c.draft_status != "aucun"),
                collecte_le: [ c.fetched_at, c.created_at ].compact.max)
    end
  end

  def statut_candidat(c)
    return "ecarte" if c.ecarte?
    return "a_verifier" if c.a_verifier?
    return "non_trie" if c.pending? && !c.enriched?

    "propose"
  end
end
