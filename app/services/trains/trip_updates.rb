require "faraday"

module Trains
  # GTFS-RT Trip Updates de la SNCF, par le relais de transport.data.gouv.fr (60 prochaines minutes, rafraîchi toutes les
  # 2 min). Le navigateur ne l'appelle jamais : seul ce service le lit, avec un cache de `CACHE` secondes.
  # Sert UNIQUEMENT à affiner l'heure de passage à Nancy-Ville (et à ne pas jouer une course supprimée) : aucun retard n'est
  # montré. Couverture garantie TGV et Intercités ; TER partielle (~85 %), le reste reste sur l'horaire théorique.
  class TripUpdates
    URL = "https://proxy.transport.data.gouv.fr/resource/sncf-gtfs-rt-trip-updates".freeze
    GARE = GtfsExtrait::GARE
    CACHE = 90.seconds
    ECHEC = 30.seconds                  # après une erreur, on ne réessaie pas avant : le théorique sert entre-temps
    CLE = "trains/trip_updates/v1".freeze
    ANNULEE = 3                         # TripDescriptor.ScheduleRelationship.CANCELED
    ARRET_SAUTE = 1                     # StopTimeUpdate.ScheduleRelationship.SKIPPED

    # { mises_a_jour: { "trip_id|yyyymmdd" => { arrivee: Time|nil, depart: Time|nil, annulee: bool } }, disponible: bool }
    def self.lire
      en_cache = Rails.cache.read(CLE)
      return en_cache if en_cache

      resultat = charger
      Rails.cache.write(CLE, resultat, expires_in: resultat[:disponible] ? CACHE : ECHEC)
      resultat
    end

    def self.charger(corps = nil)
      corps ||= telecharger
      { mises_a_jour: analyser(corps), disponible: true }
    rescue StandardError => e
      Rails.logger.warn("[trains] GTFS-RT indisponible : #{e.class} #{e.message}")
      { mises_a_jour: {}, disponible: false }
    end

    def self.telecharger
      r = Faraday.new(request: { timeout: 6, open_timeout: 3 }).get(URL)
      raise "HTTP #{r.status}" unless r.success?

      r.body
    end

    # FeedMessage { header = 1, entity = 2 repété } ; FeedEntity { id = 1, trip_update = 3 } ; TripUpdate { trip = 1,
    # stop_time_update = 2 repété } ; TripDescriptor { trip_id = 1, start_date = 3, schedule_relationship = 4 } ;
    # StopTimeUpdate { stop_id = 4, arrival = 2, departure = 3, schedule_relationship = 5 } ; StopTimeEvent { delay = 1, time = 2 }
    def self.analyser(corps)
      out = {}
      Protobuf.champs(corps).each do |num, entite|
        next unless num == 2

        mise = Protobuf.champs(entite).find { |n, _| n == 3 }&.last or next
        # les entités ne concernant pas Nancy sont écartées sans être analysées plus avant
        next unless mise.include?("-#{GARE}")

        trip = nil
        arret = nil
        Protobuf.champs(mise).each do |n, v|
          trip = Protobuf.champs(v) if n == 1
          next unless n == 2

          champs = Protobuf.champs(v)
          arret = champs if champs.any? { |nn, vv| nn == 4 && vv.end_with?("-#{GARE}") }
        end
        next unless trip

        id = trip.find { |n, _| n == 1 }&.last
        jour = trip.find { |n, _| n == 3 }&.last
        annulee = trip.find { |n, _| n == 4 }&.last == ANNULEE
        next unless id && jour

        a = d = nil
        if arret
          annulee ||= arret.find { |n, _| n == 5 }&.last == ARRET_SAUTE
          a = evenement(arret, 2)
          d = evenement(arret, 3)
        end
        out["#{id.force_encoding('UTF-8')}|#{jour}"] = { arrivee: a, depart: d, annulee: annulee }
      end
      out
    end

    def self.evenement(arret, numero)
      brut = arret.find { |n, _| n == numero }&.last or return nil
      temps = Protobuf.champs(brut).find { |n, _| n == 2 }&.last
      temps && Time.zone.at(temps)
    end
  end
end
