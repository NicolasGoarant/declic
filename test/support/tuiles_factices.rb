# Un domaine de tuiles du diorama factice, servi par le serveur des tests système sous /tuiles-test :
# le manifeste réduit de toits-v1 (test/fixtures/files/diorama), sa grille de dalles pleine, et une
# image d'un pixel pour toute dalle. Le diorama se monte donc sans réseau ni R2. S'y ajoutent le
# masque du bâti et la carte de propriété (manifestes sans dalle) et l'étalonnage publié de l'hiver :
# de quoi proposer maquette blanche et hiver. Ni automne, ni heure bleue, ni masque des arbres, ni lumières.
class TuilesFactices
  PREFIXE = "/tuiles-test".freeze
  FICHIERS = Rails.root.join("test/fixtures/files")

  def call(env)
    case env["PATH_INFO"]
    when "/toits-v1/manifeste.json" then [ 200, { "content-type" => "application/json" }, [ manifeste ] ]
    when %r{\A/toits-v1/\d+/\d+/\d+\.webp\z}, %r{\A/(masque-bati|propriete-toits-v1)/\d+/\d+/\d+\.png\z}
      [ 200, { "content-type" => "image/png" }, [ pixel ] ]
    when "/masque-bati/manifeste.json", "/propriete-toits-v1/manifeste.json"
      [ 200, { "content-type" => "application/json" }, [ { dalles: {} }.to_json ] ]
    when "/ambiances/hiver-actuelle.json"
      [ 200, { "content-type" => "application/json" }, [ FICHIERS.join("diorama/hiver-actuelle.json").read ] ]
    else [ 404, { "content-type" => "text/plain" }, [ "absente" ] ]
    end
  end

  PUBLIES = %w[toits-v1/manifeste.json masque-bati/manifeste.json propriete-toits-v1/manifeste.json
               ambiances/hiver-actuelle.json].freeze

  # Ce que sonde DioramaTuiles : ce qui est publié ici.
  def self.sonde = ->(url) { PUBLIES.any? { |p| url == "#{PREFIXE}/#{p}" } }

  private

  def pixel = @pixel ||= FICHIERS.join("pixel.png").binread

  def manifeste
    @manifeste ||= begin
      m = JSON.parse(FICHIERS.join("diorama/manifeste.json").read)
      m["dalles"] = m["grille_par_niveau"].to_h { |z, (colonnes, lignes)| [ z, (0...colonnes).to_a.product((0...lignes).to_a) ] }
      m.to_json
    end
  end
end
