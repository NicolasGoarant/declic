# La carte de « Pourquoi Déclic ? » : le vrai contour de la Métropole (public/data/contour-metropole-v1.geojson)
# projeté en SVG (équirectangulaire, longitudes réduites de cos(latitude)), et une voirie suggérée :
# des rayons partant de la place Stanislas et deux boulevards, copies réduites du contour.
module PourquoiCarte
  LARGEUR = 400.0
  MARGE = 14.0
  CENTRE = [ 6.1833, 48.6936 ].freeze # place Stanislas (lon, lat)

  module_function

  def contour
    @contour ||= JSON.parse(Rails.root.join("public/data/contour-metropole-v1.geojson").read)
                     .dig("features", 0, "geometry", "coordinates", 0)
  end

  def cadre
    @cadre ||= begin
      lons, lats = contour.transpose
      k = Math.cos(lats.sum / lats.size * Math::PI / 180)
      echelle = (LARGEUR - 2 * MARGE) / ((lons.max - lons.min) * k)
      { lon0: lons.min, lat1: lats.max, k: k, echelle: echelle, hauteur: ((lats.max - lats.min) * echelle + 2 * MARGE).round }
    end
  end

  def hauteur = cadre[:hauteur]

  # [x, y] dans le repère du SVG.
  def projeter(lon, lat)
    c = cadre
    [ (MARGE + (lon - c[:lon0]) * c[:k] * c[:echelle]).round(1), (MARGE + (c[:lat1] - lat) * c[:echelle]).round(1) ]
  end

  def chemin(points = contour.map { |lon, lat| projeter(lon, lat) })
    "M" + points.map { |x, y| "#{x} #{y}" }.join("L") + "Z"
  end

  def centre = projeter(*CENTRE)

  # Boulevards : le contour réduit autour du centre.
  def boulevards
    cx, cy = centre
    [ 0.3, 0.6 ].map do |f|
      chemin(contour.map { |lon, lat| x, y = projeter(lon, lat); [ (cx + (x - cx) * f).round(1), (cy + (y - cy) * f).round(1) ] })
    end
  end

  # Rayons légèrement courbes, du centre vers un sommet du contour sur quatorze.
  def rayons
    cx, cy = centre
    contour.each_slice(14).map(&:first).each_with_index.map do |(lon, lat), i|
      x, y = projeter(lon, lat)
      courbe = i.even? ? 0.12 : -0.12
      qx = (cx + x) / 2 - (y - cy) * courbe
      qy = (cy + y) / 2 + (x - cx) * courbe
      "M#{cx} #{cy}Q#{qx.round(1)} #{qy.round(1)} #{x} #{y}"
    end
  end

  # Point dans le polygone (lancer de rayon).
  def dans_la_metropole?(lon, lat)
    return false if lon.nil? || lat.nil?
    lon, lat = lon.to_f, lat.to_f
    dedans = false
    contour.each_cons(2) do |(x1, y1), (x2, y2)|
      dedans = !dedans if (y1 > lat) != (y2 > lat) && lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1
    end
    dedans
  end
end
