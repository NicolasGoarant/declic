# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

pin "map", to: "map.js"
pin "diorama_projection", to: "diorama_projection.js"

# Page d'accueil diorama (/labo/accueil). Leaflet et markercluster sont importés à la demande
# par le contrôleur `diorama` : preload: false, pour que les autres pages ne les tirent pas.
pin "leaflet", to: "https://cdn.jsdelivr.net/npm/leaflet@1.9.4/+esm", preload: false
pin "leaflet.markercluster", to: "https://cdn.jsdelivr.net/npm/leaflet.markercluster@1.5.3/+esm", preload: false
pin_all_from "app/javascript/diorama", under: "diorama", preload: false
