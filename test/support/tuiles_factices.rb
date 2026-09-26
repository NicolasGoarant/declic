# Un domaine de tuiles du diorama factice, servi par le serveur des tests système sous /tuiles-test :
# le manifeste réduit de toits-v1 (test/fixtures/files/diorama), sa grille de dalles pleine, et une
# image d'un pixel pour toute dalle. Le diorama se monte donc sans réseau ni R2.
class TuilesFactices
  PREFIXE = "/tuiles-test".freeze
  FICHIERS = Rails.root.join("test/fixtures/files")

  def call(env)
    case env["PATH_INFO"]
    when "/toits-v1/manifeste.json" then [ 200, { "content-type" => "application/json" }, [ manifeste ] ]
    when %r{\A/toits-v1/\d+/\d+/\d+\.webp\z} then [ 200, { "content-type" => "image/png" }, [ pixel ] ]
    else [ 404, { "content-type" => "text/plain" }, [ "absente" ] ]
    end
  end

  # Ce que sonde DioramaTuiles : seul le diorama « vrai » est publié ici.
  def self.sonde = ->(url) { url == "#{PREFIXE}/toits-v1/manifeste.json" }

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
