require "test_helper"

module Veille
  # Ne teste que l'extraction, qui est pure. Aucune requête réseau.
  class PageFetcherTest < ActiveSupport::TestCase
    def extract(html) = Veille::PageFetcher.extract(html, url: "https://exemple.fr/a")

    test "s'identifie auprès des éditeurs avec l'adresse du site" do
      assert_match %r{\+https://declic\.site}, Veille::PageFetcher::USER_AGENT
      assert_match(/Declic/i, Veille::PageFetcher::USER_AGENT)
    end

    test "lit les balises Open Graph en priorité" do
      r = extract(<<~HTML)
        <html><head>
          <title>Titre de repli</title>
          <meta property="og:title" content="À Jarville, Karim répare 400 vélos par an">
          <meta property="og:description" content="Dans son atelier associatif.">
          <meta property="article:published_time" content="2026-03-14T08:30:00+01:00">
        </head></html>
      HTML

      assert_equal "À Jarville, Karim répare 400 vélos par an", r[:title]
      assert_equal "Dans son atelier associatif.", r[:excerpt]
      assert_equal Date.new(2026, 3, 14), r[:published_on]
    end

    test "lit le JSON-LD, y compris niché dans un @graph" do
      r = extract(<<~HTML)
        <html><head><title>Repli</title>
          <script type="application/ld+json">
            {"@context":"https://schema.org","@graph":[
              {"@type":"Organization","name":"Le journal"},
              {"@type":"NewsArticle","headline":"Le jardin partagé de Laxou fête ses dix ans",
               "description":"Trente familles cultivent 800 m2.",
               "datePublished":"2026-05-02T06:00:00Z"}]}
          </script>
        </head></html>
      HTML

      assert_equal "Le jardin partagé de Laxou fête ses dix ans", r[:title]
      assert_equal "Trente familles cultivent 800 m2.", r[:excerpt]
      assert_equal Date.new(2026, 5, 2), r[:published_on]
    end

    test "retombe sur title et meta description" do
      r = extract(<<~HTML)
        <html><head>
          <title>   Un   titre   mal   espacé   </title>
          <meta name="description" content="Le chapeau classique.">
        </head></html>
      HTML

      assert_equal "Un titre mal espacé", r[:title]
      assert_equal "Le chapeau classique.", r[:excerpt]
    end

    test "ignore un bloc JSON-LD invalide sans planter" do
      r = extract(<<~HTML)
        <html><head><title>Le vrai titre</title>
          <script type="application/ld+json">{ceci n'est pas du JSON</script>
        </head></html>
      HTML

      assert_equal "Le vrai titre", r[:title]
    end

    test "une page sans métadonnée ne lève pas" do
      r = extract("<html><body>rien</body></html>")

      assert_nil r[:title]
      assert_nil r[:excerpt]
      assert_nil r[:published_on]
    end

    test "une date inexploitable devient nil plutôt qu'une valeur devinée" do
      r = extract(%(<html><head><meta property="article:published_time" content="au printemps"></head></html>))
      assert_nil r[:published_on]
    end

    test "le titre est borné pour tenir dans la colonne" do
      r = extract("<html><head><title>#{'x' * 500}</title></head></html>")
      assert_equal 250, r[:title].length
    end
  end
end
