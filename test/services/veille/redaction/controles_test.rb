require "test_helper"

class Veille::Redaction::ControlesTest < ActiveSupport::TestCase
  C = Veille::Redaction::Controles

  SOURCE = "Nadia Benali a rouvert l'atelier de réparation de vélos de Laxou en 2022. Elle y a formé 40 jeunes " \
           "du quartier. « On ne jette plus rien ici » dit-elle. L'atelier compte 3 bénévoles."

  # ~100 mots neutres, pour que la longueur ne parasite pas les tests ciblés.
  CORPS = (["Nadia répare des vélos avec les habitants de son quartier depuis plusieurs années, patiemment, ensemble."] * 8).join(" ")

  AUTRE_SOURCE = "Nadia Benali répare des vélos à Laxou avec des habitants du quartier."

  def codes(brouillon, source: SOURCE, manques: [])
    C.verifier(brouillon, source: source, manques: manques).bloquants.map(&:code).uniq
  end

  # [libellé, brouillon, code attendu]
  {
    "horaire 20h30"            => ["Les ateliers ont lieu à 20h30 dans la salle.", "horaire"],
    "horaire 9 h 15"           => ["On y vient dès 9 h 15 pour discuter.", "horaire"],
    "horaire 14:00"            => ["Rendez-vous à 14:00 devant la porte.", "horaire"],
    "horaire 18 heures"        => ["Tout démarre à 18 heures chaque fois.", "horaire"],
    "horaire de 9h à 11h"      => ["Ouvert de 9h à 11h pour tous.", "horaire"],
    "récurrence tous les"      => ["L'atelier se tient tous les mardis au local.", "horaire"],
    "récurrence chaque"        => ["Chaque samedi, des voisins se retrouvent.", "horaire"],
    "appel : inscrivez-vous"   => ["Inscrivez-vous vite pour en profiter.", "appel_a_agir"],
    "appel : venez"            => ["Venez nombreux soutenir l'atelier.", "appel_a_agir"],
    "appel : rejoignez"        => ["Rejoignez l'équipe de bénévoles.", "appel_a_agir"],
    "appel : n'hésitez pas"    => ["N'hésitez pas à pousser la porte.", "appel_a_agir"],
    "appel : pour s'inscrire"  => ["Pour s'inscrire, il suffit de passer.", "appel_a_agir"],
    "appel : découvrez"        => ["Découvrez son parcours unique.", "appel_a_agir"],
    "contact : url"            => ["Tout est sur https://atelier-laxou.fr pour les curieux.", "contact"],
    "contact : domaine nu"     => ["Le site atelier-laxou.fr raconte tout.", "contact"],
    "contact : e-mail"         => ["Écrire à nadia@atelier.fr pour la voir.", "contact"],
    "contact : téléphone"      => ["Son numéro est le 03 83 12 34 56 depuis toujours.", "contact"],
    "citation inventée"        => ["Elle répète : « Chaque vélo mérite une seconde vie ».", "citation_absente"],
    "citation entre \"\""      => ["Elle dit \"c'est une aventure humaine\" souvent.", "citation_absente"],
    "chiffre inventé"          => ["Elle a formé 120 jeunes du quartier.", "chiffre_absent"],
    "chiffre inventé (année)"  => ["Elle a rouvert l'atelier en 2019.", "chiffre_absent"]
  }.each do |libelle, (brouillon, code)|
    test "bloquant : #{libelle}" do
      assert_includes codes(brouillon), code
    end
  end

  test "bloquant : copie de plus de 15 mots d'affilée" do
    source = "Dans le quartier des Provinces à Laxou une équipe de bénévoles passionnés remet chaque semaine en état des dizaines de vieux vélos abandonnés"
    assert_includes codes(source, source: source), "copie_excessive"
  end

  test "un récit propre ne déclenche aucun bloquant" do
    texte = "Nadia Benali a rouvert l'atelier de réparation de Laxou en 2022. Depuis, elle y a formé 40 jeunes du quartier, " \
            "aidée par 3 bénévoles. « On ne jette plus rien ici », résume-t-elle."
    assert_empty codes(texte)
  end

  test "chiffres : 1 200 et 1200 sont le même nombre, mais pas 1 201" do
    source = "L'atelier a réparé 1 200 vélos."
    assert_empty codes("Il a réparé 1200 vélos.", source: source)
    assert_includes codes("Il a réparé 1 201 vélos.", source: source), "chiffre_absent"
  end

  test "citation fidèle à la source (casse et accents ignorés) : acceptée" do
    assert_empty codes("Elle le dit : « ON NE JETTE PLUS RIEN ICI ».")
  end

  test "pas de faux positif sur des mots courants" do
    assert_empty codes("Cette histoire de hasard commence chez les habitants, hors des sentiers battus.", source: "histoire")
  end

  test "avertissement de longueur hors de 90 à 160 mots, jamais bloquant" do
    r = C.verifier("Un récit bien trop court.", source: "Un récit bien trop court.")
    assert_equal ["longueur"], r.avertissements.map(&:code)
    assert_not r.bloque?

    assert_empty C.verifier(CORPS, source: AUTRE_SOURCE).avertissements.select { |a| a.code == "longueur" }, "~100 mots : dans la fourchette"

    long = (1..170).map { |i| "mot#{('a'.ord + i % 26).chr}" }.join(" ")
    assert_equal ["longueur"], C.verifier(long, source: AUTRE_SOURCE).avertissements.map(&:code)
  end

  test "avertissement champs_manquants, sans bloquer" do
    r = C.verifier(CORPS, source: AUTRE_SOURCE, manques: ["commune", " ", "personne"])
    assert_equal ["champs_manquants"], r.avertissements.map(&:code)
    assert_includes r.avertissements.first.message, "commune, personne"
    assert_not r.bloque?
  end

  test "un texte propre de bonne longueur sans manque est propre" do
    assert C.verifier(CORPS, source: AUTRE_SOURCE).propre?
  end

  test "plusieurs défauts se cumulent" do
    assert_equal %w[horaire appel_a_agir contact], codes("Venez à 20h30 sur https://x.fr")
  end

  test "sérialisation JSON aller-retour" do
    r = C.verifier("Venez à 20h30.", source: "rien")
    relu = C::Resultat.depuis_json(JSON.parse(r.as_json.to_json))
    assert_equal r.codes, relu.codes
    assert relu.bloque?
  end
end
