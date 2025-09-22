Source.create!([
  { name: "CCI Grand Nancy — Événements",  kind: :jsonld, url: "https://www.nancy.cci.fr/evenements",  active: true },
  { name: "CCI Grand Nancy — Formations",  kind: :jsonld, url: "https://www.nancy.cci.fr/formations",  active: true },
  { name: "Lorr’Up — Événements",          kind: :jsonld, url: "https://www.lorr-up.fr/evenements/",    active: true },
  { name: "Lorr’Up — Actualités",          kind: :jsonld, url: "https://www.lorr-up.fr/actualites/",    active: true }
])
puts "OK: #{Source.count} sources"
