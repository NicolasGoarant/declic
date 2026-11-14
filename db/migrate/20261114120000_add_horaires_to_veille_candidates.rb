# Heure de début et de fin de l'événement (créneau du jour), à côté de starts_on / ends_on / schedule_text
# (la périodicité) qui existaient déjà. Reportées à la validation sur Opportunity#start_time / end_time.
class AddHorairesToVeilleCandidates < ActiveRecord::Migration[7.2]
  def change
    add_column :veille_candidates, :start_time, :time
    add_column :veille_candidates, :end_time, :time
  end
end
