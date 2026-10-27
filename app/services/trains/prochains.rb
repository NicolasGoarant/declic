module Trains
  # Les passages à Nancy-Ville dans les minutes qui viennent : l'horaire théorique du GTFS, affiné par le GTFS-RT quand il
  # connaît la course. Ne rend que ce que le diorama sait jouer (heures, catégorie, côtés) : ni retard ni perturbation.
  # Une course supprimée n'est pas rendue (la rame ne passera pas).
  class Prochains
    PASSE = 10.minutes                  # un train déjà à quai (ou qui vient de partir) doit encore pouvoir se jouer
    FUTUR = 30.minutes

    def self.liste(maintenant = Time.current, horaires: Horaires.new, relais: TripUpdates)
      return { passages: [], theorique: false, temps_reel: false } unless horaires.disponible?

      temps_reel = relais.lire
      mises = temps_reel[:mises_a_jour]
      passages = horaires.passages(maintenant - PASSE - 30.minutes, maintenant + FUTUR + 30.minutes).filter_map do |p|
        mise = mises["#{p[:id]}|#{p[:jour]}"]
        next if mise && mise[:annulee]

        arrivee = p[:arrivee] && (mise&.dig(:arrivee) || p[:arrivee])
        depart = p[:depart] && (mise&.dig(:depart) || p[:depart])
        # un retard peut renverser l'ordre arrivée/départ côté source : on garde l'arrivée avant le départ
        depart = arrivee if arrivee && depart && depart < arrivee
        fin = depart || arrivee
        debut = arrivee || depart
        next if fin < maintenant - PASSE || debut > maintenant + FUTUR

        { id: "#{p[:id]}|#{p[:jour]}", categorie: p[:categorie], entree: p[:entree], sortie: p[:sortie],
          arrivee: arrivee&.to_i, depart: depart&.to_i, source: mise ? "temps_reel" : "theorique" }
      end
      { passages: passages, theorique: true, temps_reel: temps_reel[:disponible] }
    end
  end
end
