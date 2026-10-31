# Configuration Anthropic.
#
# ANTHROPIC_MODEL reste le modèle par défaut historique. Le chantier veille
# ne s'appuie pas dessus : il choisit explicitement son modèle par passe
# (voir Veille::AiEnricher et Veille::Redaction::Brouillon).
Rails.application.config.x.anthropic = {
  api_key: ENV["ANTHROPIC_API_KEY"],
  model:   ENV.fetch("ANTHROPIC_MODEL", "claude-sonnet-5")
}
