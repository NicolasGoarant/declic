require "test_helper"
require_relative "support"
require_relative "fake_anthropic_client"

# Frontière se_former / pratiquer : le modèle tranche (nature d'abord, durée ensuite), le code garde
# la famille rendue et en déduit la catégorie (formation / rencontres). Le client est simulé : ces
# tests couvrent la règle donnée au modèle et ce que le code en fait, pas le jugement du modèle.
class Veille::AiEnricherFrontiereTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 10, 13)

  def enrich(candidate, **reponse)
    client = FakeAnthropicClient.new(text: reponse_ia(**reponse).to_json)
    Veille::AiEnricher.new(client: client).enrich(candidate, today: TODAY)
    candidate.reload
  end

  test "le prompt donne la règle des deux côtés de la frontière" do
    regle = Veille::AiEnricher.prompt_for(title: "T", text: "x")[:system][/SE_FORMER OU PRATIQUER[^\n]*/]

    assert regle, "règle de frontière présente"
    assert_match(/Visée professionnelle.*reconversion : se_former/, regle)
    assert_match(/Loisir.*week-end.*: pratiquer/, regle)
    assert_match(/Une rubrique « Atelier » n'est jamais se_former/, regle)
  end

  test "côté se_former : formation à visée professionnelle → catégorie formation" do
    c = enrich(candidat(title: "Reconversion : CAP cuisine en 10 mois (GRETA)", full_text: "Formation certifiante."),
               famille: "se_former", date_debut: "2026-11-03", date_fin: "2027-09-30")

    assert_equal "se_former", c.famille
    assert_equal "formation", c.declic_category
    assert_equal "opportunite", c.item_type
  end

  test "côté pratiquer : atelier de loisir d'un week-end → catégorie rencontres" do
    c = enrich(candidat(title: "Atelier poterie en famille", full_text: "Un week-end pour modeler son bol."),
               famille: "pratiquer", date_debut: "2026-11-14", date_fin: "2026-11-15")

    assert_equal "pratiquer", c.famille
    assert_equal "rencontres", c.declic_category
    assert_equal "opportunite", c.item_type
  end

  test "deux fiches voisines de part et d'autre de la frontière gardent chacune leur famille" do
    cours_langue = enrich(candidat(title: "Cours d'anglais, niveau B1, 30 semaines"), famille: "se_former")
    cours_loisir = enrich(candidat(title: "Cours de dessin du jeudi soir"), famille: "pratiquer")

    assert_equal %w[se_former pratiquer], [cours_langue.famille, cours_loisir.famille]
    assert_equal %w[formation rencontres], [cours_langue.declic_category, cours_loisir.declic_category]
  end

  test "une série d'ateliers de même intitulé garde la même famille à chaque date" do
    familles = %w[2026-11-04 2026-11-11 2026-11-18].map do |jour|
      enrich(candidat(title: "Atelier couture"), famille: "pratiquer", date_debut: jour).famille
    end
    assert_equal ["pratiquer"], familles.uniq
  end

  test "l'origine transentreprise garde sa catégorie même en se_former" do
    c = enrich(candidat(origin: "transentreprise", declic_category: "entreprendre"), famille: "se_former")
    assert_equal "se_former", c.famille
    assert_equal "entreprendre", c.declic_category
  end

  test "les deux familles sont proposées au modèle et connues du modèle Opportunity" do
    assert_includes Veille::AiEnricher::FAMILLES_OPPORTUNITE, "se_former"
    assert_includes Veille::AiEnricher::FAMILLES_OPPORTUNITE, "pratiquer"
    assert_equal ["Se former", "Pratiquer"], Opportunity::FAMILLES.values_at("se_former", "pratiquer")
  end
end
