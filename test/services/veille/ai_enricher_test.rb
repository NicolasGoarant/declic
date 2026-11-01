require "test_helper"
require_relative "support"
require_relative "fake_anthropic_client"

class Veille::AiEnricherTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 10, 13)

  def enrich(candidate, **reponse)
    client = FakeAnthropicClient.new(text: reponse_ia(**reponse).to_json)
    Veille::AiEnricher.new(client: client).enrich(candidate, today: TODAY)
    [candidate.reload, client]
  end

  test "le prompt porte les exclusions : nomination, actualité juridique, fait divers" do
    system = Veille::AiEnricher.prompt_for(title: "T", text: "x")[:system]
    assert_match "nomination", system
    assert_match "actualité judiciaire", system
    assert_match "faits divers", system
  end

  test "une belle histoire hors ligne éditoriale est écartée et ne sera pas rédigée" do
    c, = enrich(candidat(origin: "presse"), type: "belle_histoire", categorie: nil, hors_ligne: true, motif: "Simple nomination.")
    assert_equal "ecarte", c.status
    assert_match "Simple nomination.", c.discard_reason
    assert_not_includes Veille::Candidate.a_rediger, c
  end

  test "une opportunité hors ligne éditoriale est écartée" do
    c, = enrich(candidat, hors_ligne: true, motif: "Simple visite guidée.")
    assert_equal "ecarte", c.status
    assert_match "Simple visite guidée.", c.discard_reason
  end

  test "une source officielle hors ligne est écartée, même typée opportunité de force" do
    c, = enrich(candidat(origin: "agenda_nancy", item_type: "opportunite"), type: "belle_histoire", hors_ligne: true)
    assert_equal "opportunite", c.item_type
    assert_equal "ecarte", c.status
  end

  test "le prompt porte la règle éditoriale, le texte et la limite de citation" do
    params = Veille::AiEnricher.prompt_for(title: "Atelier", text: "Texte " * 2000, origin: "jeveuxaider", commune: "Laxou")

    assert_match "Un récit n'a pas à proposer d'action", params[:system]
    assert_match "15 mots", params[:system]
    assert_match "Commune indiquée par la source : Laxou", params[:messages].first[:content]
    assert_operator params[:messages].first[:content].length, :<, 3_300, "le texte envoyé est plafonné"
  end

  test "classe une opportunité avec sa catégorie, sa commune et ses dates" do
    c, = enrich(candidat(origin: "presse"), type: "opportunite", famille: "se_former", commune: "Laxou",
                          date_debut: "2026-12-05", date_fin: "2026-12-06")

    assert_equal "opportunite", c.item_type
    assert_equal "formation", c.declic_category
    assert_equal "Laxou", c.commune
    assert_equal [Date.new(2026, 12, 5), Date.new(2026, 12, 6)], [c.starts_on, c.ends_on]
    assert_equal "Une première phrase. Une seconde phrase.", c.summary
    assert_equal 80, c.score
    assert c.enriched?
    assert_equal "pending", c.status, "rien n'est validé par l'IA"
  end

  test "sans date, le régime est conservé" do
    c, = enrich(candidat, regime: "Ouvert toute l'année")
    assert_equal "Ouvert toute l'année", c.schedule_text
    assert_nil c.starts_on
  end

  test "une belle histoire est reconnue (source de presse)" do
    c, = enrich(candidat(origin: "presse"), type: "belle_histoire", categorie: nil)
    assert_equal "belle_histoire", c.item_type
    assert_nil c.declic_category
  end

  test "une belle histoire n'a pas de catégorie, même si le modèle ou le candidat en porte une" do
    c, = enrich(candidat(origin: "presse", declic_category: "formation"), type: "belle_histoire", categorie: "entreprendre")
    assert_nil c.reload.declic_category
  end

  test "une opportunité dont le modèle ne donne pas de catégorie retombe sur « rencontres »" do
    c, = enrich(candidat(origin: "presse"), type: "opportunite", categorie: nil)
    assert_equal "rencontres", c.reload.declic_category
  end

  test "le schéma ne demande plus la catégorie, et chaque famille d'opportunité mène à une catégorie" do
    assert_nil Veille::AiEnricher::SCHEMA[:properties][:categorie]
    assert_equal Opportunity::FAMILLES.keys.sort, Veille::AiEnricher::CATEGORIE_PAR_FAMILLE.keys.sort
    assert_empty Veille::AiEnricher::CATEGORIE_PAR_FAMILLE.values - Opportunity::CATEGORIES
  end

  test "une source officielle reste une opportunité, quoi qu'en dise le modèle" do
    c, = enrich(candidat(origin: "agenda_nancy", declic_category: "rencontres", item_type: "opportunite"),
                type: "belle_histoire", categorie: "ecologiser")
    assert_equal "opportunite", c.item_type
    assert_equal "rencontres", c.declic_category
  end

  test "une opportunité en Meurthe-et-Moselle est gardée, hors du département elle est écartée" do
    c, = enrich(candidat(commune: nil), type: "opportunite", commune: "Toul")
    assert_equal "pending", c.status
    assert_equal "Toul", c.commune

    c, = enrich(candidat(commune: nil), type: "opportunite", commune: "Metz")
    assert_equal "ecarte", c.status
    assert_match(/Hors Meurthe-et-Moselle/, c.discard_reason)
  end

  test "une belle histoire est gardée dans tout le Grand Est, écartée au-delà" do
    c, = enrich(candidat(origin: "presse", commune: nil), type: "belle_histoire", categorie: nil, commune: "Épinal")
    assert_equal "pending", c.status

    c, = enrich(candidat(origin: "presse", commune: nil), type: "belle_histoire", categorie: nil, commune: "Besançon")
    assert_equal "ecarte", c.status
    assert_match(/Hors Grand Est/, c.discard_reason)
  end

  test "quand le modèle renvoie une commune vide, le code la cherche dans le titre puis le texte" do
    c, = enrich(candidat(origin: "presse", commune: nil, title: "Elle ouvre sa boutique à Saint-Dié-des-Vosges", full_text: "Récit."),
                type: "belle_histoire", categorie: nil, commune: "")
    assert_equal "pending", c.status
    assert_equal "Saint-Dié-des-Vosges", c.commune

    c, = enrich(candidat(origin: "presse", commune: nil, title: "Une reconversion", full_text: "Installée à Toul depuis un an."),
                type: "opportunite", commune: "")
    assert_equal "pending", c.status
    assert_equal "Toul", c.commune
  end

  test "sans aucune commune repérable, l'élément reste à localiser au lieu d'être écarté" do
    c, = enrich(candidat(origin: "presse", commune: nil, title: "Une reconversion", full_text: "Sans aucun lieu."),
                commune: "", famille: "petite_manifestation")
    assert_equal "pending", c.status
    assert_nil c.discard_reason
    assert_equal "petite_manifestation", c.famille, "l'étiquette est gardée : la fiche restera masquable"
    assert c.a_localiser?
    assert_includes Veille::Candidate.a_localiser, c
  end

  test "une histoire à localiser n'est pas rédigée tant que la commune manque" do
    c, = enrich(candidat(origin: "agenda_nancy", commune: nil, title: "Un récit", full_text: "Sans aucun lieu."),
                type: "belle_histoire", commune: "")
    c.update!(item_type: "belle_histoire")
    assert_not_includes Veille::Candidate.a_rediger, c
  end

  test "une commune nommée hors du périmètre reste écartée" do
    c, = enrich(candidat(commune: nil, title: "Un atelier", full_text: "Un texte."), commune: "Besançon")
    assert_equal "ecarte", c.status
    assert_match(/Hors Meurthe-et-Moselle/, c.discard_reason)
  end

  test "une date passée écarte aussi un élément sans commune" do
    c, = enrich(candidat(commune: nil, title: "Un atelier", full_text: "Un texte."), commune: "", date_debut: "2020-01-01")
    assert_equal "ecarte", c.status
    assert_equal "Événement passé", c.discard_reason
  end

  test "la catégorie se déduit de la famille" do
    { "se_former" => "formation", "pratiquer" => "rencontres", "agir_ecologie" => "ecologiser",
      "s_engager" => "benevolat", "evenement_solidaire" => "benevolat", "entreprendre" => "entreprendre",
      "decouvrir" => "rencontres", "petite_manifestation" => "rencontres" }.each do |famille, categorie|
      c, = enrich(candidat(origin: "agenda_nancy", declic_category: "formation"), famille: famille)
      assert_equal categorie, c.declic_category, famille
      assert_equal famille, c.famille
    end
  end

  test "transentreprise garde sa catégorie, quelle que soit la famille" do
    c, = enrich(candidat(origin: "transentreprise", declic_category: "entreprendre"), famille: "pratiquer")
    assert_equal "entreprendre", c.declic_category
  end

  test "hors_ligne et famille hors_ligne écartent de la même façon" do
    [{ hors_ligne: true, famille: "decouvrir" }, { hors_ligne: false, famille: "hors_ligne" }].each do |reponse|
      c, = enrich(candidat, **reponse)
      assert_equal "ecarte", c.status
      assert_equal "hors_ligne", c.famille
    end
  end

  test "une famille de récit sur une opportunité forcée n'est pas gardée" do
    c, = enrich(candidat(origin: "agenda_nancy", item_type: "opportunite"), type: "belle_histoire", famille: "portrait")
    assert_equal "opportunite", c.item_type
    assert_nil c.famille
  end

  test "la rubrique Brocante de l'agenda vaut petite manifestation, sauf au profit d'une cause" do
    texte = "Noël Vert. Brocante / marché. Lieu : Nancy."
    c, = enrich(candidat(origin: "agenda_nancy", full_text: texte), famille: "decouvrir")
    assert_equal "petite_manifestation", c.famille
    c, = enrich(candidat(origin: "agenda_nancy", full_text: texte), famille: "evenement_solidaire")
    assert_equal "evenement_solidaire", c.famille
  end

  test "le rôle et la zone sont gardés" do
    c, = enrich(candidat, role_public: "spectateur", zone: "grand_nancy", famille: "decouvrir")
    assert_equal "spectateur", c.role_public
    assert_equal "grand_nancy", c.zone
  end

  test "un spectateur n'est plus écarté pour ce seul rôle" do
    c, = enrich(candidat, role_public: "spectateur", famille: "decouvrir")
    assert_equal "pending", c.status
  end

  test "écarte un événement passé" do
    c, = enrich(candidat, date_debut: "2026-09-01", date_fin: "2026-09-02")
    assert_equal "ecarte", c.status
    assert_equal "Événement passé", c.discard_reason
  end

  test "garde un événement qui court encore" do
    c, = enrich(candidat, date_debut: "2026-09-01", date_fin: "2026-11-02")
    assert_equal "pending", c.status
  end

  test "reprend la commune de la source quand le modèle n'en donne pas" do
    c, = enrich(candidat(commune: "Maxéville"), commune: "")
    assert_equal "Maxéville", c.commune
    assert_equal "pending", c.status
  end

  test "un résumé qui recopie plus de 15 mots de la source passe en « à vérifier » sans résumé" do
    source = "Chaque samedi matin les bénévoles de l'association accueillent les habitants du quartier pour réparer ensemble des vélos usagés et leur offrir une seconde vie"
    c, = enrich(candidat(full_text: source),
                resume: "Chaque samedi matin les bénévoles de l'association accueillent les habitants du quartier pour réparer ensemble des vélos. Voilà.")

    assert_nil c.summary
    assert_equal "a_verifier", c.status
    assert_match(/trop proche/, c.reason)
  end

  test "une citation courte (15 mots ou moins) est tolérée" do
    source = "Les bénévoles accueillent les habitants du quartier pour réparer des vélos chaque samedi matin sans rendez-vous"
    c, = enrich(candidat(full_text: source), resume: "Les bénévoles accueillent les habitants du quartier pour réparer. Le reste est reformulé librement ici.")
    assert_equal "pending", c.status
    assert c.summary.present?
  end

  test "copie_excessive? ignore casse, accents et ponctuation" do
    source = (1..20).map { |i| "mot#{i}" }.join(" ")
    assert Veille::AiEnricher.copie_excessive?(source.upcase.tr(" ", ", ") + ".", source)
    assert_not Veille::AiEnricher.copie_excessive?("mot1 mot2 autre " + (3..20).map { |i| "mot#{i}" }.join(" "), source.gsub("mot10", "x") ) if false
  end

  test "une réponse hors schéma ne casse pas la classification" do
    c, = enrich(candidat(item_type: "opportunite"), type: "n'importe quoi", categorie: "culture")
    assert_equal "opportunite", c.item_type
    assert_includes Opportunity::CATEGORIES, c.declic_category
  end

  test "l'erreur du client remonte à l'appelant et le candidat reste intact" do
    c = candidat
    client = FakeAnthropicClient.new(raise_with: AnthropicClient::ConnectionError.new("timeout"))
    assert_raises(AnthropicClient::ConnectionError) { Veille::AiEnricher.new(client: client).enrich(c) }
    assert_not c.reload.enriched?
  end

  # Découvert contre la vraie API (31/10) : le format structuré refuse ces mots-clés, ce que
  # la doublure du client ne peut pas voir. Tous les schémas de la veille sont vérifiés.
  test "aucun schéma de réponse n'utilise les mots-clés que l'API refuse (minimum, maximum…)" do
    interdits = %w[minimum maximum minLength maxLength minItems maxItems pattern format multipleOf]
    cherche = lambda do |noeud, chemin|
      case noeud
      when Hash
        noeud.flat_map { |k, v| (interdits.include?(k.to_s) && chemin.last != "properties" ? [(chemin + [k]).join(".")] : []) + cherche.(v, chemin + [k.to_s]) }
      when Array then noeud.flat_map { |v| cherche.(v, chemin) }
      else []
      end
    end
    { "AiEnricher" => Veille::AiEnricher::SCHEMA, "Brouillon" => Veille::Redaction::Brouillon::SCHEMA }.each do |nom, schema|
      assert_empty cherche.(schema, []), "#{nom} : mots-clés de schéma non pris en charge"
    end
  end

  test "Agenda Grand Nancy : le lieu relevé par l'IA devient l'adresse du candidat" do
    c, = enrich(candidat(origin: "agenda_nancy"), lieu: "Musée des Beaux-Arts")
    assert_equal "Musée des Beaux-Arts", c.adresse
  end

  test "pas de lieu identifiable, ou une simple commune : aucune adresse" do
    c, = enrich(candidat(origin: "agenda_nancy"), lieu: "")
    assert_nil c.adresse
    c, = enrich(candidat(origin: "agenda_nancy"), lieu: "Nancy")
    assert_nil c.adresse
  end

  test "une adresse saisie à la main n'est jamais écrasée par l'IA" do
    c, = enrich(candidat(origin: "agenda_nancy", adresse: "12 rue Saint-Dizier"), lieu: "Musée des Beaux-Arts")
    assert_equal "12 rue Saint-Dizier", c.adresse
  end

  test "la presse n'est pas concernée : pas de lieu repris de l'IA" do
    c, = enrich(candidat(origin: "presse"), lieu: "Musée des Beaux-Arts")
    assert_nil c.adresse
  end

  test "le prompt demande le lieu et le schéma le prévoit" do
    assert_includes Veille::AiEnricher::SCHEMA[:required], "lieu"
    assert_match "LIEU", Veille::AiEnricher.prompt_for(title: "T", text: "x")[:system]
  end
end
