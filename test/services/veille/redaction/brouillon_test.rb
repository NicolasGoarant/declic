require "test_helper"
require_relative "../support"
require_relative "../fake_anthropic_client"

class Veille::Redaction::BrouillonTest < ActiveSupport::TestCase
  include VeilleSupport

  B = Veille::Redaction::Brouillon

  # Environ 100 mots, sans horaire, appel, contact, citation ni chiffre : passe tous les contrôles.
  RECIT = "Elle a rouvert la porte d'un ancien atelier de couture, au cœur du quartier, après des années de silence. " \
          "Depuis, des voisins viennent y apprendre les gestes de la réparation, ceux que leurs grands-mères connaissaient. " \
          "Chacun repart avec un vêtement remis en état et le sentiment d'avoir retrouvé un savoir-faire. " \
          "Autour de la machine à coudre, les conversations se nouent et le quartier se redécouvre. " \
          "L'atelier est devenu un lieu où l'on se rencontre autant qu'on y apprend."

  def histoire(**attrs)
    candidat(**{ origin: "presse", item_type: "belle_histoire", commune: "Laxou", title: "Une couturière rouvre l'atelier",
               summary: "Une couturière rouvre un atelier de réparation à Laxou. Les voisins y apprennent la couture.",
               excerpt: "Dans le quartier, un atelier renaît.", full_text: nil }.merge(attrs))
  end

  def reponse(brouillon: RECIT, personne: "Nadia Benali", manques: [])
    { brouillon: brouillon, personne: personne, champs_manquants: manques }.to_json
  end

  def client(**opts) = FakeAnthropicClient.new(text: reponse, usage: { "input_tokens" => 400, "output_tokens" => 200 }, **opts)

  test "le prompt porte la règle éditoriale : environ 120 mots, ni horaires ni appel à l'action, reformulation, rien d'inventé" do
    params = B.prompt_for(histoire)
    assert_match "120 mots", params[:system]
    assert_match "ni horaires ni appel à l'action", params[:system]
    assert_match "REFORMULATION INTÉGRALE", params[:system]
    assert_match "champs_manquants", params[:system]
    assert_equal "json_schema", params[:output_config][:format][:type]
  end

  test "mode automatique : titre, résumé et chapeau, jamais le texte intégral du tampon" do
    c = histoire(full_text: "TEXTE INTÉGRAL DE L'ARTICLE qui ne doit pas partir")
    cl = client
    B.new(client: cl).draft(c)

    assert_includes cl.user_content, "Résumé : Une couturière rouvre"
    assert_includes cl.user_content, "Chapeau : Dans le quartier"
    assert_not_includes cl.user_content, "TEXTE INTÉGRAL"
  end

  test "mode manuel : le texte collé est envoyé, tronqué à 12 000 caractères" do
    c = histoire
    cl = client
    B.new(client: cl, profil: :web).draft(c, texte: "x" * 15_000)

    assert_includes cl.user_content, "Texte de l'article :"
    assert_equal 12_000, cl.user_content[/x{100,}/].length
  end

  test "enregistre le récit avec la source et l'accord à obtenir, statut rédigé" do
    c = histoire
    B.new(client: client).draft(c)
    c.reload

    assert_equal "redige", c.draft_status
    assert_equal 1, c.draft_attempts
    assert_includes c.draft_body, "Elle a rouvert la porte"
    assert_includes c.draft_body, "Source : Presse locale — #{c.url}"
    assert_includes c.draft_body, "Accord de la personne : à obtenir"
    assert_equal [], c.draft_manques
    assert_equal [], c.draft_controles["bloquants"]
  end

  test "l'accord obtenu est daté dans les mentions" do
    texte = B.finaliser("Récit.", source_label: "Presse locale", url: "https://x.fr", accord_obtenu_at: Time.zone.local(2026, 11, 3, 9))
    assert_includes texte, "Accord de la personne : obtenu le 03/11/2026"
  end

  test "la consommation est journalisée (passe rédaction, Sonnet)" do
    c = histoire
    B.new(client: client).draft(c)

    appel = c.appels_ia.sole
    assert_equal ["redaction", "ok", B::MODEL], [appel.passe, appel.statut, appel.modele]
    assert_in_delta (400 * 3 + 200 * 15) / 1_000_000.0, appel.cout_usd.to_f, 1e-6
  end

  test "un brouillon refusé par les contrôles est conservé, à vérifier, et l'appel est requalifié" do
    c = histoire
    cl = FakeAnthropicClient.new(text: reponse(brouillon: "Venez à 20h30 découvrir son atelier."), usage: { "input_tokens" => 10, "output_tokens" => 10 })
    B.new(client: cl).draft(c)
    c.reload

    assert_equal "a_verifier", c.draft_status
    assert_includes c.draft_body, "Venez à 20h30"
    assert_includes c.draft_controles["bloquants"].map { |b| b["code"] }, "horaire"
    assert_equal "refuse_controle", c.appels_ia.sole.statut
  end

  test "les champs manquants sont enregistrés, et « personne » est ajouté si personne n'est nommé" do
    c = histoire
    cl = FakeAnthropicClient.new(text: reponse(personne: "", manques: ["commune"]))
    B.new(client: cl).draft(c)

    assert_equal %w[commune personne], c.reload.draft_manques
    assert_includes c.draft_controles["avertissements"].map { |a| a["code"] }, "champs_manquants"
  end

  test "incident d'API : à reprendre, essai compté, erreur relancée" do
    c = histoire
    cl = FakeAnthropicClient.new(raise_with: AnthropicClient::ConnectionError.new("timeout"))

    assert_raises(AnthropicClient::ConnectionError) { B.new(client: cl).draft(c) }
    c.reload
    assert_equal ["a_reprendre", 1], [c.draft_status, c.draft_attempts]
    assert_nil c.draft_body
  end

  test "réponse illisible : à reprendre aussi" do
    c = histoire
    assert_raises(Veille::AiPass::ParseError) { B.new(client: FakeAnthropicClient.new(text: "oups")).draft(c) }
    assert_equal ["a_reprendre", 1], [c.reload.draft_status, c.draft_attempts]
  end

  test "plafond atteint : rien n'est envoyé et l'essai n'est pas compté" do
    Veille::AppelIa.create!(passe: "redaction", modele: "m", statut: "ok", cout_usd: 15)
    c = histoire
    cl = client

    assert_raises(Veille::Plafond::Depasse) { B.new(client: cl).draft(c) }
    assert_empty cl.calls
    assert_equal ["aucun", 0], [c.reload.draft_status, c.draft_attempts]
  end

  test "ne rédige rien sans résumé ni texte" do
    assert_raises(ArgumentError) { B.new(client: client).draft(histoire(summary: nil)) }
  end

  test "un texte collé suffit même sans résumé" do
    c = histoire(summary: nil)
    assert_nothing_raised { B.new(client: client, profil: :web).draft(c, texte: "Un article complet.") }
  end

  test "profil web : 5 s + 22 s, aucun nouvel essai, sous les 30 s d'Heroku ; profil lot : plus patient" do
    recu = {}
    AnthropicClient.stub(:new, ->(**kw) { recu[kw[:timeout]] = kw; Object.new }) do
      B.new(profil: :web).send(:client)
      B.new.send(:client)
    end
    assert_equal 0, recu.fetch(22)[:retries]
    assert_equal 1, recu.fetch(40)[:retries]
    assert_equal B::MODEL, recu.fetch(22)[:model]
    assert_operator B::OPEN_TIMEOUT + B::PROFILS[:web][:timeout], :<, 30
  end

  test "les contrôles s'appliquent à la source réellement envoyée (citation présente dans le texte collé : acceptée)" do
    c = histoire
    cl = FakeAnthropicClient.new(text: reponse(brouillon: RECIT + " Elle dit : « on répare ensemble »."))
    B.new(client: cl, profil: :web).draft(c, texte: "Elle explique : on répare ensemble, entre voisins.")
    assert_equal "redige", c.reload.draft_status
  end
end
