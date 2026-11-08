# Les occupations saisonnières des places (sapin, grande roue, patinoire, marché de Noël…) : config/diorama/occupations_places.yml.
#
# Le fichier est lu et vérifié une fois ; la page reçoit TOUTES les installations (une poignée) avec les adresses de leurs
# images, et le navigateur montre celles dont la période contient le jour de Nancy (diorama/occupations.js). Ajouter une
# installation ne demande que d'éditer le YAML.
class DioramaOccupations
  FICHIER = Rails.root.join("config/diorama/occupations_places.yml")
  CHAMPS = %w[id nom place debut fin position sprite zooms].freeze
  # Bornes larges de la Métropole : une position hors de ce cadre est une faute de saisie (lat et lon inversées…).
  LAT = (48.55..48.80).freeze
  LON = (6.05..6.35).freeze

  class Invalide < StandardError; end

  # Relu à chaque page en développement (on retouche le YAML sans redémarrer), gardé ailleurs.
  def self.toutes
    return new.installations if Rails.env.development?
    @toutes ||= new.installations
  end

  # Une faute de saisie ne doit jamais casser l'accueil : sans installations, le diorama reste tel quel (le test du modèle,
  # lui, échoue sur le même fichier).
  def self.pour_js
    toutes
  rescue Invalide, Psych::Exception, ArgumentError, TypeError, KeyError => e
    Rails.logger.error("[DioramaOccupations] #{FICHIER} ignoré : #{e.message}")
    []
  end

  def self.oublier! = (@toutes = nil)

  def initialize(fichier = FICHIER)
    @donnees = YAML.safe_load_file(fichier, permitted_classes: [ Date ]) || {}
  end

  # [{ id, nom, place, debut: "AAAA-MM-JJ", fin, lat, lon, altitude_m, zooms, image, lumieres, ancre, k }]
  def installations
    sprites = @donnees.fetch("sprites", {}) || {}
    ids = []
    (@donnees["installations"] || []).map do |i|
      manque = CHAMPS.reject { |c| i.key?(c) && !i[c].nil? }
      raise Invalide, "#{i['id'] || i.inspect} : champs manquants #{manque.join(', ')}" if manque.any?
      id = i["id"]
      raise Invalide, "#{id} : identifiant en double" if ids.include?(id)
      ids << id
      debut, fin = date(i, "debut"), date(i, "fin")
      raise Invalide, "#{id} : fin (#{fin}) avant début (#{debut})" if fin < debut
      pos = i["position"]
      lat, lon = Float(pos["lat"]), Float(pos["lon"])
      raise Invalide, "#{id} : position hors de la Métropole (#{lat}, #{lon})" unless LAT.cover?(lat) && LON.cover?(lon)
      zooms = Array(i["zooms"]).map { |z| Integer(z) }
      raise Invalide, "#{id} : zooms hors de 0..9 (#{zooms.inspect})" if zooms.empty? || zooms.any? { |z| !(0..9).cover?(z) }
      sprite = sprites[i["sprite"]] or raise Invalide, "#{id} : sprite inconnu « #{i['sprite']} »"
      {
        id: id, nom: i["nom"], place: i["place"], debut: debut.iso8601, fin: fin.iso8601,
        lat: lat, lon: lon, altitude_m: pos["altitude_m"]&.to_f, zooms: zooms,
        image: image(id, sprite["image"]), lumieres: sprite["lumieres"] && image(id, sprite["lumieres"]),
        ancre: Array(sprite["ancre_px"]).map(&:to_f), k: Float(sprite["px_par_pixel_mosaique"])
      }
    end
  end

  private

  def date(i, champ)
    v = i[champ]
    v.is_a?(Date) ? v : Date.iso8601(v.to_s)
  rescue Date::Error
    raise Invalide, "#{i['id']} : #{champ} illisible (#{v.inspect}), attendu AAAA-MM-JJ"
  end

  def image(id, chemin)
    raise Invalide, "#{id} : image absente app/assets/images/#{chemin}" unless Rails.root.join("app/assets/images", chemin.to_s).file?
    ActionController::Base.helpers.image_path(chemin)
  end
end
