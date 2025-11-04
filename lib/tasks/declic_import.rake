# lib/tasks/declic_import.rake
# Rake tasks Déclic — import CSV + désactivation automatique selon starts_at/ends_at
#
# Usage :
#   bin/rails declic:import_csv CSV=collector/opportunities_local.fixed.csv
#   bin/rails declic:deactivate_expired
#   bin/rails declic:refresh_activity  # (désactive ce qui est passé, réactive ce qui redevient à venir)
#
# Options :
#   DRY_RUN=true  -> ne fait que simuler et logguer
#   ONLY_DEACTIVATE=true -> sur import, n’active pas explicitement les futurs (prudent)

require "csv"

namespace :declic do
  # ---------- Helpers ----------
  def boolify(v, default=nil)
    return default if v.nil?
    s = v.is_a?(String) ? v.strip.downcase : v
    return true  if s == true  || s == "true"  || s == "1" || s == 1
    return false if s == false || s == "false" || s == "0" || s == 0
    default
  end

  def parse_time_zone(str)
    return nil if str.to_s.strip.empty?
    Time.zone.parse(str.to_s) rescue nil
  end

  def expired?(starts_at, ends_at, now)
    return false if starts_at.nil? && ends_at.nil?
    return true  if ends_at && ends_at < now
    # Evénements datés sans fin explicite : si start est passé, on considère expiré
    return true  if ends_at.nil? && starts_at && starts_at < now
    false
  end

  def upcoming?(starts_at, ends_at, now)
    return false if starts_at.nil? && ends_at.nil?
    return true  if starts_at && starts_at >= now
    return true  if ends_at && ends_at >= now
    false
  end

  # ---------- Import CSV avec auto-(dés)activation ----------
  desc "Importe des opportunités depuis un CSV (et désactive automatiquement celles dont la date est passée)"
  task :import_csv, [:CSV] => :environment do |t, args|
    path = args[:CSV] || ENV["CSV"]
    abort "→ CSV manquant (passer CSV=...)" unless path && File.exist?(path)

    dry_run         = boolify(ENV["DRY_RUN"], false)
    only_deactivate = boolify(ENV["ONLY_DEACTIVATE"], false)
    now             = Time.zone.now

    created = 0
    updated = 0
    same    = 0
    errs    = []

    puts "→ Import CSV : #{path}"
    puts "   DRY_RUN=#{dry_run}  ONLY_DEACTIVATE=#{only_deactivate}"

    CSV.foreach(path, headers: true, encoding: "utf-8") do |row|
      begin
        attrs = row.to_h.transform_keys(&:to_s)

        title   = attrs["title"].to_s.strip
        org     = attrs["organization"].to_s.strip
        loc     = attrs["location"].to_s.strip

        if title.blank?
          errs << { title: "(vide)", error: "Title can't be blank" }
          next
        end

        # clé d’upsert : titre + org + lieu (ajuste si tu préfères une autre clé)
        opp = Opportunity.find_or_initialize_by(title: title, organization: org, location: loc)

        # mapping simple
        permitted = %w[
          title description category organization location time_commitment
          latitude longitude tags image_url source_url
        ]
        opp.assign_attributes(attrs.slice(*permitted))

        # booleans & dates
        starts_at = parse_time_zone(attrs["starts_at"])
        ends_at   = parse_time_zone(attrs["ends_at"])

        opp.starts_at = starts_at if opp.respond_to?(:starts_at=)
        opp.ends_at   = ends_at   if opp.respond_to?(:ends_at=)

        # is_active demandé dans le CSV ?
        csv_is_active = boolify(attrs["is_active"], nil)

        # logique d’activité :
        # - si expiré -> false
        # - sinon :
        #     * si ONLY_DEACTIVATE=true : on ne force pas true (on respecte csv_is_active s'il est fourni)
        #     * sinon on met true si à venir
        if expired?(starts_at, ends_at, now)
          new_active = false
        else
          new_active =
            if only_deactivate
              csv_is_active.nil? ? (opp.is_active.nil? ? true : opp.is_active) : csv_is_active
            else
              # activer si à venir, sinon respecter csv_is_active (ou true par défaut)
              upcoming?(starts_at, ends_at, now) ? true : (csv_is_active.nil? ? true : csv_is_active)
            end
        end
        opp.is_active = new_active

        # comparaison pour stats
        changed = opp.changed?

        if dry_run
          puts "• [DRY] #{opp.new_record? ? 'NEW' : (changed ? 'UPD' : 'SAME')}  #{title}"
        else
          if opp.save
            if opp.previous_changes.key?("id")
              created += 1
            elsif changed
              updated += 1
            else
              same += 1
            end
          else
            errs << { title: title, error: opp.errors.full_messages.join(", ") }
          end
        end

      rescue => e
        errs << { title: row["title"], error: e.message }
      end
    end

    puts
    puts "✅ Import terminé"
    puts "   • créés:      #{created}"
    puts "   • mis à jour: #{updated}"
    puts "   • inchangés:  #{same}"
    puts "   • erreurs:    #{errs.size}"
    if errs.any?
      puts "—— Détails erreurs ——"
      errs.first(50).each_with_index do |h, i|
        puts "[#{i+1}] #{h[:error]}\n     titre: #{h[:title]}"
      end
      puts "  (…#{[errs.size-50, 0].max} de plus)" if errs.size > 50
    end
  end

  # ---------- Balayage : désactiver ce qui est passé ----------
  desc "Désactive toutes les opportunités expirées (selon starts_at/ends_at)"
  task :deactivate_expired => :environment do
    now = Time.zone.now
    scope = Opportunity.where(is_active: true)

    to_deactivate = scope.where(
      Opportunity.arel_table[:ends_at].lt(now)
      .or(Opportunity.arel_table[:starts_at].lt(now).and(Opportunity.arel_table[:ends_at].eq(nil)))
    )

    count = 0
    to_deactivate.find_each do |opp|
      opp.update(is_active: false)
      count += 1
    end

    puts "✅ Désactivation terminée — #{count} opportunité(s) désactivée(s)."
  end

  # ---------- Balayage : réactiver ce qui est à venir ----------
  desc "Réactive les opportunités à venir (si datées dans le futur) et active par défaut celles sans dates (option pragmatique)"
  task :reactivate_future => :environment do
    now = Time.zone.now
    table = Opportunity.arel_table

    # à venir si start >= now ou (start nil et end >= now)
    future = Opportunity.where(is_active: [false, nil]).where(
      table[:starts_at].gteq(now)
      .or(table[:ends_at].gteq(now))
    )

    reactivated = 0
    future.find_each do |opp|
      opp.update(is_active: true)
      reactivated += 1
    end

    puts "✅ Réactivation terminée — #{reactivated} opportunité(s) réactivée(s)."
  end

  # ---------- Balayage complet pratique ----------
  desc "Désactive le passé et réactive l’à-venir (rafraîchit l’état d’activité)"
  task :refresh_activity => :environment do
    Rake::Task["declic:deactivate_expired"].invoke
    Rake::Task["declic:reactivate_future"].invoke
  end
end
