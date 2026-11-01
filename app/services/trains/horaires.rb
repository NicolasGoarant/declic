require "json"

module Trains
  # Les horaires théoriques de Nancy-Ville, lus dans l'extrait du GTFS (`GtfsExtrait`).
  #
  # L'extrait vit à deux endroits : `tmp/trains/nancy.json` (le plus récent, réécrit par `rake trains:extrait` ou par le
  # rafraîchissement paresseux ci-dessous) et `db/trains/nancy.json` (livré avec l'application, pour qu'elle fonctionne dès
  # le déploiement). Le web ne bloque jamais sur le téléchargement : s'il date de plus de `VALIDITE`, une tâche de fond
  # le refait pendant que l'ancien continue de servir (Heroku efface `tmp/` au redémarrage d'un dyno, d'où le fichier livré).
  class Horaires
    VALIDITE = 7 * 24 * 3600
    FUSEAU = "Europe/Paris".freeze
    LIVRE = Rails.root.join("db/trains/nancy.json")
    FRAIS = Rails.root.join("tmp/trains/nancy.json")

    class << self
      def courant
        @verrou ||= Mutex.new
        @verrou.synchronize do
          charger
          rafraichir_en_fond if perime?
          @donnees
        end
      end

      # pour les tests : repart d'un état vide
      def oublier!
        @donnees = @fichier = @charge_le = @en_cours = nil
      end

      def perime?(donnees = @donnees)
        return true unless donnees

        Time.zone.parse(donnees["genere_le"]) < VALIDITE.seconds.ago || donnees["fenetre"][1] < (Time.zone.today + 2).strftime("%Y%m%d")
      rescue StandardError
        true
      end

      def ecrire(extrait, chemin = FRAIS)
        FileUtils.mkdir_p(File.dirname(chemin))
        temporaire = "#{chemin}.#{Process.pid}.tmp"
        File.write(temporaire, JSON.generate(extrait))
        File.rename(temporaire, chemin)
      end

      private

      def charger
        fichier = [FRAIS, LIVRE].select { |f| File.exist?(f) }.max_by { |f| JSON.parse(File.read(f))["genere_le"] rescue "" }
        return if fichier.nil? || (@fichier == fichier && @charge_le == File.mtime(fichier))

        @donnees = JSON.parse(File.read(fichier))
        @fichier = fichier
        @charge_le = File.mtime(fichier)
      rescue JSON::ParserError => e
        Rails.logger.error("[trains] extrait illisible (#{fichier}) : #{e.message}")
      end

      def rafraichir_en_fond
        return if @en_cours || Rails.env.test?

        @en_cours = Thread.new do
          Rails.application.executor.wrap do
            ecrire(GtfsExtrait.generer)
            Rails.logger.info("[trains] extrait GTFS rafraîchi")
          rescue StandardError => e
            Rails.logger.error("[trains] rafraîchissement du GTFS impossible : #{e.class} #{e.message}")
          ensure
            @en_cours = nil
          end
        end
      end
    end

    # ─── Les passages dans une fenêtre ─────────────────────────────────────────────────────────────────────────
    # Rend les arrêts à Nancy-Ville dont l'intervalle [arrivée, départ] touche [debut, fin] (Time) :
    # { id, jour (yyyymmdd), categorie, arrivee, depart (Time ou nil), entree, sortie }
    def initialize(donnees = self.class.courant)
      @d = donnees
    end

    def disponible?
      !@d.nil?
    end

    def passages(debut, fin)
      return [] unless @d

      zone = ActiveSupport::TimeZone[FUSEAU]
      jours = ((debut - 1.day).in_time_zone(zone).to_date..fin.in_time_zone(zone).to_date).map { |j| j.strftime("%Y%m%d") }
      circule = jours.to_h { |j| [j, @d["services"].select { |_, l| l.include?(j) }.keys.to_set] }
      out = []
      jours.each do |jour|
        minuit = zone.parse(jour)
        @d["trajets"].each do |t|
          next unless circule[jour].include?(t["s"])

          arrivee = t["a"] && minuit_plus(minuit, t["a"])
          depart = t["d"] && minuit_plus(minuit, t["d"])
          debut_arret, fin_arret = arrivee || depart, depart || arrivee
          next if fin_arret < debut || debut_arret > fin

          out << { id: t["id"], jour: jour, categorie: t["c"], arrivee: arrivee, depart: depart, entree: t["e"], sortie: t["x"] }
        end
      end
      out.sort_by { |p| p[:arrivee] || p[:depart] }
    end

    private

    # les heures GTFS peuvent dépasser 24:00:00 (après minuit, même jour de service) : on ajoute des secondes à minuit
    def minuit_plus(minuit, secondes)
      Time.zone.at(minuit.to_i + secondes)
    end
  end
end
