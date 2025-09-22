# frozen_string_literal: true
module Support
  module FrenchDateParser
    MONTHS = {
      "janvier"=>1,"février"=>2,"fevrier"=>2,"mars"=>3,"avril"=>4,"mai"=>5,"juin"=>6,
      "juillet"=>7,"août"=>8,"aout"=>8,"septembre"=>9,"octobre"=>10,"novembre"=>11,"décembre"=>12,"decembre"=>12
    }.freeze

    # Exemples gérés :
    #  "Jeudi 16 octobre 2025 de 09h30 à 11h30"  -> 2025-10-16 09:30
    #  "6 octobre 2025 - 10 octobre 2025"       -> 2025-10-06 09:00 (heure par défaut si absente)
    #  "20 novembre 2025 8h30"                  -> 2025-11-20 08:30
    def parse_french_datetime(text, default_hour: 9, default_min: 0, zone: "Europe/Paris")
      return nil if text.nil? || text.strip.empty?
      t = ActiveSupport::Inflector.transliterate(text.downcase)
      # 1) date + heure "16 octobre 2025 09h30"
      if t =~ /(\d{1,2})\s+([a-zéêèûôîç]+)\s+(20\d{2}).*?(\d{1,2})h(\d{2})?/
        d, m_name, y, hh, mm = $1.to_i, $2, $3.to_i, $4.to_i, ($5 || "0").to_i
        m = MONTHS[m_name] || 1
        return ActiveSupport::TimeZone[zone].local(y, m, d, hh, mm)
      end
      # 2) date seule "16 octobre 2025"
      if t =~ /(\d{1,2})\s+([a-zéêèûôîç]+)\s+(20\d{2})/
        d, m_name, y = $1.to_i, $2, $3.to_i
        m = MONTHS[m_name] || 1
        return ActiveSupport::TimeZone[zone].local(y, m, d, default_hour, default_min)
      end
      # 3) plage "6 octobre 2025 - 10 octobre 2025" -> on prend le début
      if t =~ /(\d{1,2})\s+([a-zéêèûôîç]+)\s+(20\d{2})\s*[-–]\s*(\d{1,2})\s+([a-zéêèûôîç]+)\s+(20\d{2})/
        d, m1, y, _d2, _m2, _y2 = $1.to_i, $2, $3.to_i, $4.to_i, $5, $6.to_i
        m = MONTHS[m1] || 1
        return ActiveSupport::TimeZone[zone].local(y, m, d, default_hour, default_min)
      end
      nil
    end
    module_function :parse_french_datetime
  end
end
