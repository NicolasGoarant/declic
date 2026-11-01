require "test_helper"
require "minitest/mock"
require "zip"

class TrainsTest < ActiveSupport::TestCase
  # ─── mini-encodeur protobuf pour fabriquer un flux GTFS-RT ───
  def varint(n)
    out = +"".b
    loop do
      octet = n & 0x7f
      n >>= 7
      out << (n.zero? ? octet : octet | 0x80).chr
      break if n.zero?
    end
    out
  end

  def champ(num, valeur)
    if valeur.is_a?(Integer)
      varint(num << 3) + varint(valeur)
    else
      varint((num << 3) | 2) + varint(valeur.bytesize) + valeur.b
    end
  end

  def evenement(temps) = champ(2, temps)

  def flux(trip_id, jour, arrivee: nil, depart: nil, relation: nil)
    arret = champ(4, "StopPoint:OCETrain TER-87141002")
    arret = champ(2, evenement(arrivee)) + arret if arrivee
    arret = champ(3, evenement(depart)) + arret if depart
    trip = champ(1, trip_id) + champ(3, jour)
    trip += champ(4, relation) if relation
    mise = champ(1, trip) + champ(2, arret)
    champ(1, champ(1, "1.0")) + champ(2, champ(1, "e1") + champ(3, mise))
  end

  # ─── extrait du GTFS ───
  def zip_de_test
    fichiers = {
      "feed_info.txt" => "feed_id,feed_publisher_name,feed_publisher_url,feed_lang,feed_start_date,feed_end_date,feed_version\n0,SNCF,x,fr,20261026,20270331,2026-10-26\n",
      "stops.txt" => "stop_id,stop_name,stop_lat,stop_lon\nStopPoint:OCETrain TER-87141002,Nancy,48.69,6.1746\nStopPoint:OCETrain TER-87141077,Frouard,48.75,6.14\nStopPoint:OCETrain TER-87141010,Jarville,48.67,6.20\nStopPoint:OCECar TER-87141002,Nancy,48.69,6.1746\nStopPoint:OCECar TER-87999999,Ailleurs,48.0,6.0\n",
      "trips.txt" => "route_id,service_id,trip_id,trip_headsign,direction_id,block_id,shape_id\nr,S1,T1,,0,,\nr,S1,T2,,0,,\nr,S1,T3,,0,,\nr,S2,T4,,0,,\n",
      "calendar_dates.txt" => "service_id,date,exception_type\nS1,20261028,1\nS1,20261029,1\nS1,20301029,1\nS2,20261028,2\n",
      "stop_times.txt" => <<~CSV
        trip_id,arrival_time,departure_time,stop_id,stop_sequence,stop_headsign,pickup_type,drop_off_type,shape_dist_traveled
        T1,07:00:00,07:00:00,StopPoint:OCETrain TER-87141077,0,,0,0,
        T1,07:20:00,07:22:00,StopPoint:OCETrain TER-87141002,1,,0,0,
        T1,07:30:00,07:30:00,StopPoint:OCETrain TER-87141010,2,,0,0,
        T2,08:00:00,08:00:00,StopPoint:OCETrain TER-87141010,0,,0,0,
        T2,08:10:00,08:10:00,StopPoint:OCETrain TER-87141002,1,,0,0,
        T3,09:00:00,09:00:00,StopPoint:OCECar TER-87999999,0,,0,0,
        T3,09:30:00,09:30:00,StopPoint:OCECar TER-87141002,1,,0,0,
        T4,10:00:00,10:00:00,StopPoint:OCETrain TER-87141002,0,,0,0,
        T4,10:30:00,10:30:00,StopPoint:OCETrain TER-87141077,1,,0,0,
      CSV
    }
    chemin = File.join(Dir.mktmpdir, "g.zip")
    Zip::File.open(chemin, create: true) { |z| fichiers.each { |nom, contenu| z.get_output_stream(nom) { |f| f.write(contenu) } } }
    chemin
  end

  test "l'extrait garde les courses de Nancy, leurs côtés et leurs jours, sans les cars ni les courses sans service" do
    extrait = Trains::GtfsExtrait.generer(zip_de_test, aujourdhui: Date.new(2026, 10, 27))
    assert_equal %w[T1 T2], extrait[:trajets].map { |t| t[:id] }
    t1, t2 = extrait[:trajets]
    assert_equal({ c: "ter", a: 7 * 3600 + 20 * 60, d: 7 * 3600 + 22 * 60, e: "N", x: "SE" }, t1.slice(:c, :a, :d, :e, :x))
    assert_equal({ a: 8 * 3600 + 10 * 60, d: nil, e: "SE", x: nil }, t2.slice(:a, :d, :e, :x))
    assert_equal({ "S1" => %w[20261028 20261029] }, extrait[:services])
  end

  # ─── lecture des passages ───
  def horaires
    Trains::Horaires.new(JSON.parse(JSON.generate(Trains::GtfsExtrait.generer(zip_de_test, aujourdhui: Date.new(2026, 10, 27)))))
  end

  test "les passages d'une fenêtre sont en heure de Paris, un jour de service sans circulation donne rien" do
    zone = ActiveSupport::TimeZone["Europe/Paris"]
    passages = horaires.passages(zone.parse("2026-10-28 07:15"), zone.parse("2026-10-28 08:15"))
    assert_equal %w[T1 T2], passages.map { |p| p[:id] }
    assert_equal zone.parse("2026-10-28 07:20"), passages[0][:arrivee]
    assert_empty horaires.passages(zone.parse("2026-10-27 07:15"), zone.parse("2026-10-27 08:15"))
  end

  # ─── GTFS-RT ───
  test "le GTFS-RT donne l'heure réelle, et une course supprimée est écartée" do
    t = Time.zone.at(1_793_000_000)
    mises = Trains::TripUpdates.analyser(flux("T1", "20261028", arrivee: t.to_i + 300, depart: t.to_i + 420) +
                                         flux("T2", "20261028", relation: 3))
    assert_equal t + 300, mises["T1|20261028"][:arrivee]
    assert_equal t + 420, mises["T1|20261028"][:depart]
    assert mises["T2|20261028"][:annulee]
  end

  test "Prochains affine par le temps réel, ne montre que la fenêtre et retombe sur le théorique si le relais est KO" do
    zone = ActiveSupport::TimeZone["Europe/Paris"]
    maintenant = zone.parse("2026-10-28 07:10")
    retard = zone.parse("2026-10-28 07:25").to_i
    relais = Struct.new(:r) { def lire = r }
    avec = relais.new({ mises_a_jour: Trains::TripUpdates.analyser(flux("T1", "20261028", arrivee: retard, depart: retard + 120)), disponible: true })
    liste = Trains::Prochains.liste(maintenant, horaires: horaires, relais: avec)
    assert_equal %w[T1], liste[:passages].map { |p| p[:id].split("|").first }
    assert_equal retard, liste[:passages][0][:arrivee]
    assert_equal "temps_reel", liste[:passages][0][:source]

    hors = relais.new({ mises_a_jour: {}, disponible: false })
    liste = Trains::Prochains.liste(maintenant, horaires: horaires, relais: hors)
    assert_equal zone.parse("2026-10-28 07:20").to_i, liste[:passages][0][:arrivee]
    assert_equal "theorique", liste[:passages][0][:source]
    assert_equal false, liste[:temps_reel]

    annule = relais.new({ mises_a_jour: Trains::TripUpdates.analyser(flux("T1", "20261028", relation: 3)), disponible: true })
    assert_empty Trains::Prochains.liste(maintenant, horaires: horaires, relais: annule)[:passages]
  end

  test "un relais illisible ou en panne ne casse rien" do
    assert_equal({ mises_a_jour: {}, disponible: false }, Trains::TripUpdates.charger("\xff\xff\xff".b))
    Trains::TripUpdates.stub(:telecharger, -> { raise Faraday::TimeoutError }) do
      assert_equal false, Trains::TripUpdates.charger[:disponible]
    end
  end
end
