require "csv"
require "faraday"
require "json"
require "tempfile"
require "zip"

module Trains
  # Extrait du GTFS théorique de la SNCF limité à Nancy-Ville (UIC 87141002) : un petit JSON (quelques centaines de ko) à la
  # place d'un zip de 5 Mo (80 Mo de stop_times). Pour chaque course qui s'y arrête : catégorie commerciale, heures
  # d'arrivée et de départ, côté d'où la rame vient et où elle va (N = Frouard et au-delà, SE = Jarville et au-delà), et ses
  # jours de circulation sur la fenêtre. Données SNCF, licence ODbL (voir la page « Sources des données »).
  class GtfsExtrait
    URL = "https://eu.ftp.opendatasoft.com/sncf/plandata/Export_OpenData_SNCF_GTFS_NewTripId.zip".freeze
    GARE = "87141002".freeze
    GARE_LON = 6.174579                  # à l'ouest : côté nord (Champigneulles, Frouard, Toul, Paris) ; à l'est : côté sud-est
    JOURS_AVANT = 1
    JOURS_APRES = 21
    FORMAT = "declic/trains-nancy".freeze
    CATEGORIES = {                       # préfixe du stop_id (StopPoint:OCE<préfixe>-<UIC>) → catégorie de rame
      "Train TER" => "ter", "TGV INOUI" => "tgv", "OUIGO" => "tgv", "INTERCITES" => "ic"
    }.freeze                             # cars (« Car TER », « Car à réservation ») exclus : pas de rails

    def self.generer(zip_path = nil, aujourdhui: Time.zone.today)
      new(aujourdhui).generer(zip_path)
    end

    def initialize(aujourdhui)
      @debut = aujourdhui - JOURS_AVANT
      @fin = aujourdhui + JOURS_APRES
    end

    def generer(zip_path = nil)
      zip_path ||= telecharger
      Zip::File.open(zip_path) do |zip|
        lieux = lire_lieux(zip)
        trajets = lire_horaires(zip, lieux)
        services = lire_services(zip, trajets.map { |t| t[:s] }.uniq)
        trajets.select! { |t| services[t[:s]]&.any? }
        {
          format: FORMAT, version: 1, genere_le: Time.current.iso8601, gare: GARE,
          source: "SNCF, GTFS théorique (licence ODbL)", feed: lire_feed(zip),
          fenetre: [@debut.strftime("%Y%m%d"), @fin.strftime("%Y%m%d")],
          services: services.select { |_, jours| jours.any? }, trajets: trajets
        }
      end
    ensure
      @temp&.close!
    end

    private

    def telecharger
      @temp = Tempfile.new(["gtfs-sncf", ".zip"], binmode: true)
      reponse = Faraday.new(request: { timeout: 120, open_timeout: 10 }).get(URL)
      raise "GTFS SNCF : HTTP #{reponse.status}" unless reponse.success?

      @temp.write(reponse.body)
      @temp.flush
      @temp.path
    end

    def lire_feed(zip)
      ligne = CSV.parse(zip.read("feed_info.txt"), headers: true).first
      { version: ligne["feed_version"], debut: ligne["feed_start_date"], fin: ligne["feed_end_date"] }
    end

    # stop_id → [nom, longitude] pour tous les points d'arrêt (les voisins de Nancy servent à choisir le côté)
    def lire_lieux(zip)
      lieux = {}
      CSV.parse(zip.read("stops.txt"), headers: true).each { |l| lieux[l["stop_id"]] = l["stop_lon"].to_f }
      lieux
    end

    def cote(lieux, stop_id)
      return nil unless stop_id

      lon = lieux[stop_id]
      lon && (lon < GARE_LON ? "N" : "SE")
    end

    def heure(texte)
      return nil if texte.nil? || texte.empty?

      h, m, s = texte.split(":").map(&:to_i)
      (h * 3600) + (m * 60) + s
    end

    # stop_times.txt est trié par course : une passe, une course en mémoire à la fois
    def lire_horaires(zip, lieux)
      brut = []
      courant = nil
      arrets = []
      vider = lambda do
        trajet = trajet_depuis(courant, arrets, lieux) if courant
        brut << trajet if trajet
        arrets = []
      end
      zip.get_input_stream("stop_times.txt") do |flux|
        premiere = true
        flux.each_line do |ligne|
          (premiere = false; next) if premiere

          champs = ligne.chomp.split(",", 6)
          trip = champs[0]
          if trip != courant
            vider.call
            courant = trip
          end
          arrets << champs
        end
      end
      vider.call
      services_des_courses(zip, brut)
    end

    def trajet_depuis(trip, arrets, lieux)
      i = arrets.index { |a| a[3].end_with?("-#{GARE}") }
      return nil unless i

      point = arrets[i][3]
      prefixe = point[/\AStopPoint:OCE(.+)-#{GARE}\z/, 1]
      categorie = CATEGORIES[prefixe] or return nil
      arrivee = heure(arrets[i][1])
      depart = heure(arrets[i][2])
      precedent = i.positive? ? arrets[i - 1][3] : nil
      suivant = arrets[i + 1]&.fetch(3)
      { id: trip, c: categorie, a: i.zero? ? nil : arrivee, d: suivant ? depart : nil,
        e: cote(lieux, precedent), x: cote(lieux, suivant) }
    end

    def services_des_courses(zip, trajets)
      voulus = trajets.to_h { |t| [t[:id], t] }
      CSV.parse(zip.read("trips.txt"), headers: true).each do |l|
        t = voulus[l["trip_id"]]
        t[:s] = l["service_id"] if t
      end
      trajets.select { |t| t[:s] }
    end

    def lire_services(zip, ids)
      ids = ids.to_set
      jours = Hash.new { |h, k| h[k] = [] }
      d0, d1 = @debut.strftime("%Y%m%d"), @fin.strftime("%Y%m%d")
      CSV.parse(zip.read("calendar_dates.txt"), headers: true).each do |l|
        next unless l["exception_type"] == "1" && ids.include?(l["service_id"])

        jours[l["service_id"]] << l["date"] if l["date"] >= d0 && l["date"] <= d1
      end
      jours.transform_values(&:sort)
    end
  end
end
