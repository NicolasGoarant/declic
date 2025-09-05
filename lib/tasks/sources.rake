# frozen_string_literal: true
namespace :sources do
  desc "Ajouter une source (ENV: KIND=ics|rss NAME='...' URL='...')"
  task add: :environment do
    kind = ENV['KIND'] or abort "KIND manquant (ics|rss)"
    name = ENV['NAME'] or abort "NAME manquant"
    url  = ENV['URL']  or abort "URL manquante"

    s = Source.find_or_initialize_by(name: name)
    s.assign_attributes(kind: kind, url: url, enabled: true)
    s.save!
    puts "OK: id=#{s.id} [#{s.kind}] #{s.enabled? ? 'ON' : 'OFF'} #{s.name} -> #{s.url}"
  end

  desc "Lister les sources"
  task list: :environment do
    puts "ID | KIND | ON | NAME | URL"
    Source.order(:id).each do |s|
      puts "#{s.id}\t#{s.kind}\t#{s.enabled?}\t#{s.name}\t#{s.url}"
    end
  end

  desc "Lancer l'ingestion de toutes les sources actives"
  task run: :environment do
    Ingestors.run_all!
    puts "Ingestion terminée."
  end

  desc "Lancer l'ingestion d'UNE source par nom (rails 'sources:run_one[name=...]')"
  task :run_one, [:name] => :environment do |_, args|
    name = args[:name] || ENV['NAME'] or abort "NAME manquant"
    src  = Source.find_by!(name: name)
    Ingestors.run_source!(src)
    puts "Ingestion '#{name}' OK."
  end
end
