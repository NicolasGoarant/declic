require "net/http"

# Où sont publiées les tuiles du diorama, et quelles couches y répondent vraiment.
#
# La maquette v3 de nancy-3d compose trois sortes de fond : le « Vrai Nancy » (lot toits-v1),
# la « Maquette blanche » (toits-v1 éclairci là où le masque du bâti dit qu'il y a un
# bâtiment) et les ambiances (un grade par dalle, qui lit aussi la carte de propriété).
# Chaque couche dont un fichier manque sur le domaine est retirée de l'interface.
#
# La présence est SONDÉE côté serveur (requêtes HEAD, résultat gardé en mémoire) : sonder
# depuis le navigateur laisserait une erreur 404 dans la console à chaque visite.
#
# Convention de publication, à suivre par nancy-3d/publier-r2.py : chaque dossier publié
# porte un manifeste.json, et c'est sa présence qui vaut publication. Les ambiances se
# sondent sur leur propre fichier de paramètres.
class DioramaTuiles
  URL_DEFAUT = "https://tuiles-declic.mist-media.eu".freeze

  # Styles du « Vrai Nancy » : même grille, mêmes niveaux (0 à 8), même format ({z}/{x}/{y}.webp) ;
  # seul le grade des dalles change. Par défaut : Jeu vidéo. Un style dont le manifeste manque sur
  # R2 est retiré de la liste (masqué côté panneau Calques).
  STYLES = { "jeu-video-v2" => "Jeu vidéo", "toits-v1" => "Réaliste" }.freeze
  STYLE_DEFAUT = "jeu-video-v2".freeze
  MASQUE = "masque-bati".freeze             # {z}/{x}/{y}.png, niveaux 6 à 8, centre-ville
  PROPRIETE = "propriete-toits-v1".freeze   # 8/{x}/{y}.png (pas de dossier dalles/)
  AMBIANCES_DOSSIER = "ambiances".freeze    # {nom}-actuelle.json (format nancy-3d/ambiance)
  AMBIANCES = %w[heure-bleue automne hiver].freeze
  ARBRES = "masque-arbres".freeze           # {z}/{x}/{y}.png, niveaux 6 à 8, blanc = feuillage (automne)
  # Lampadaires de la nuit (format nancy-3d/lumieres-nuit, points au niveau 8) : les lanternes
  # relevées si elles sont publiées un jour, sinon les positions procédurales IGN BD TOPO®.
  LAMPADAIRES = [ %w[lumieres-nuit lanternes.json], %w[lampadaires-bdtopo lampadaires-bdtopo.json] ].freeze

  DUREE_CACHE = 10.minutes
  DELAI_SONDE_S = 2
  CACHE = {}
  VERROU = Mutex.new

  attr_reader :base

  # `sonde` : appelable qui reçoit une URL et rend true si elle répond 200 (injectable en test).
  def initialize(base: ENV["DIORAMA_TILES_URL"].presence || URL_DEFAUT, sonde: nil)
    @base = base.chomp("/")
    @sonde = sonde || method(:repond?)
  end

  def url(chemin) = "#{base}/#{chemin}"

  # Ce que la page peut proposer. Une couche n'est disponible que si TOUT ce qu'elle lit l'est.
  # Le masque du bâti, la carte de propriété, les arbres et les lampadaires décrivent la géométrie
  # de la maquette (pas son rendu) : ils valent pour tous les styles, pas seulement celui choisi.
  def disponibles
    p = presents
    styles = STYLES.keys.select { |lot| p.fetch(url("#{lot}/manifeste.json")) }
    vrai = styles.any?
    blanche = vrai && p.fetch(url("#{MASQUE}/manifeste.json"))
    propriete = p.fetch(url("#{PROPRIETE}/manifeste.json"))
    ambiances = AMBIANCES.select { |nom| blanche && propriete && p.fetch(url(parametres_ambiance(nom))) }
    # Couches facultatives : sans elles, l'automne se replie sur les verts sombres et la nuit reste sans lumières.
    arbres = vrai && p.fetch(url("#{ARBRES}/manifeste.json"))
    lumieres = vrai && lampadaires(p).present?
    { vrai: vrai, styles: styles, blanche: blanche, ambiances: ambiances, arbres: arbres, lumieres: lumieres }
  end

  # Ce que reçoit le contrôleur Stimulus.
  def pour_js
    {
      base: base, styles: STYLES.keys, style_defaut: STYLE_DEFAUT, masque: MASQUE, propriete: PROPRIETE,
      arbres: ARBRES, lumieres: lampadaires(presents),
      ambiances: AMBIANCES.index_with { |nom| parametres_ambiance(nom) },
      disponibles: disponibles
    }
  end

  private

  def parametres_ambiance(nom) = "#{AMBIANCES_DOSSIER}/#{nom}-actuelle.json"

  # Chemin du fichier de lampadaires publié (le premier de LAMPADAIRES), ou nil.
  def lampadaires(p)
    dossier, fichier = LAMPADAIRES.find { |d, _| p.fetch(url("#{d}/manifeste.json")) }
    dossier && "#{dossier}/#{fichier}"
  end

  def urls_a_sonder
    [ *STYLES.keys, MASQUE, PROPRIETE, ARBRES, *LAMPADAIRES.map(&:first) ].map { |dossier| url("#{dossier}/manifeste.json") } +
      AMBIANCES.map { |nom| url(parametres_ambiance(nom)) }
  end

  def presents
    VERROU.synchronize do
      entree = CACHE[base]
      return entree[:resultat] if entree && entree[:le] > DUREE_CACHE.ago
    end
    resultat = urls_a_sonder.map { |u| Thread.new { [ u, @sonde.call(u) ] } }.to_h(&:value)
    VERROU.synchronize { CACHE[base] = { le: Time.current, resultat: resultat } }
    resultat
  end

  def repond?(adresse)
    uri = URI(adresse)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: DELAI_SONDE_S, read_timeout: DELAI_SONDE_S) do |http|
      http.head(uri.request_uri).is_a?(Net::HTTPOK)
    end
  rescue StandardError => e
    Rails.logger.info("[DioramaTuiles] #{adresse} injoignable : #{e.class}")
    false
  end
end
