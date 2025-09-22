# frozen_string_literal: true

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.base_uri    :self

  # Leaflet via CDN
  policy.script_src  :self, "https://unpkg.com"
  policy.style_src   :self, "https://unpkg.com", :unsafe_inline

  # IMAGES : toutes les images HTTPS + data/blob (tuiles, marqueurs, unsplash…)
  policy.img_src     :self, :https, "data:", "blob:"

  # XHR/fetch (on appelle /opportunities.json)
  policy.connect_src :self

  # (optionnel) fonts si besoin
  policy.font_src    :self, :https, "data:"
end

Rails.application.config.content_security_policy_report_only = false
