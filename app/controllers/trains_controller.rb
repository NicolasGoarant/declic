# Relais des horaires de trains pour le diorama : le navigateur n'appelle jamais la SNCF ni transport.data.gouv.fr, il lit
# ceci (GTFS théorique + GTFS-RT en cache côté serveur). `maintenant` (secondes Unix du serveur) cale l'horloge du client.
class TrainsController < ApplicationController

  def prochains
    maintenant = heure_d_essai || Time.current
    donnees = Trains::Prochains.liste(maintenant)
    response.headers["Cache-Control"] = "no-store"   # `maintenant` cale l'horloge du client : jamais une réponse périmée
    render json: donnees.merge(maintenant: maintenant.to_i)
  rescue StandardError => e
    Rails.logger.error("[trains] #{e.class} #{e.message}")
    render json: { passages: [], theorique: false, temps_reel: false, maintenant: Time.current.to_i }
  end

  private

  # ?a=HH:MM[:SS] : joue le relais à cette heure de Nancy aujourd'hui (essais en pointe ou en creux), hors production
  def heure_d_essai
    return if Rails.env.production? || !params[:a].to_s.match?(/\A\d{1,2}:\d{2}(:\d{2})?\z/)

    Time.find_zone("Europe/Paris").parse(params[:a])
  end
end
