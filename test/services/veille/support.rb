# Aides communes aux tests de la veille automatique.
module VeilleSupport
  # Faux client HTTP : renvoie des corps préparés par URL, retient les appels.
  class FakeHttp
    attr_reader :appels

    def initialize(reponses = {})
      @reponses = reponses
      @appels   = []
    end

    def get(url, **_opts)
      @appels << url
      r = @reponses.fetch(url) { raise Veille::Http::Error, "pas de réponse prévue pour #{url}" }
      raise r if r.is_a?(Exception)
      r
    end
  end

  def item(**attrs)
    Veille::Item.new({ origin: "agenda_nancy", url: "https://exemple.fr/#{SecureRandom.hex(3)}", title: "Un titre",
                       text: "Un texte.", commune: "Nancy", reliability: "haute" }.merge(attrs))
  end

  def reponse_ia(**attrs)
    { "type" => "opportunite", "categorie" => "rencontres", "commune" => "Nancy", "date_debut" => "", "date_fin" => "",
      "regime" => "", "hors_ligne" => false, "resume" => "Une première phrase. Une seconde phrase.", "confiance" => 80,
      "motif" => "Invite à venir." }.merge(attrs.transform_keys(&:to_s))
  end

  def candidat(**attrs)
    Veille::Candidate.create!({ url: "https://exemple.fr/#{SecureRandom.hex(4)}", title: "Un titre", origin: "agenda_nancy",
                                full_text: "Un texte source." }.merge(attrs))
  end
end
