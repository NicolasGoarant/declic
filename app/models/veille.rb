# Namespace du chantier de veille éditoriale.
#
# Le préfixe de table isole complètement ce chantier des tables
# d'ingestion existantes (sources, raw_ingestions) : aucune collision
# possible, ni de table, ni de classe.
module Veille
  def self.table_name_prefix
    "veille_"
  end
end
