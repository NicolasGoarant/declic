# Reprise des dates d'une opportunité vers starts_on / ends_on / start_time / end_time.
# Utilisée par la migration de données (ReprendDatesDesOpportunites) et, en lecture seule,
# par le rapport `declic:dates_rapport`. Ne sauvegarde rien : `changements` est à appliquer
# par l'appelant, `cas` dit ce qui a été rencontré.
#
#   - start_date / end_date ISO (AAAA-MM-JJ)            -> starts_on / ends_on       (:iso)
#   - texte libre, schedule_text vide ou déjà ce texte    -> schedule_text            (:texte_bascule)
#   - texte libre, schedule_text déjà rempli d'autre chose -> rien, chaîne conservée (:texte_conserve)
#   - starts_at / ends_at avec starts_on / ends_on vide   -> date + heure de Paris    (:reconcilie)
#   - ni début ni fin à l'arrivée                         -> opportunité permanente   (:permanente)
#
# Un starts_at à minuit UTC pile est une date saisie sans heure (imports) : on garde le jour
# UTC et aucune heure, sinon il deviendrait « 1h » ou « 2h » à Paris.
class ConversionDates
  FUSEAU = "Europe/Paris".freeze

  # Seul l'ISO strict compte comme une date ; tout le reste est du texte libre.
  def self.date_iso(valeur)
    texte = valeur.to_s.strip
    return nil unless texte.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.iso8601(texte)
  rescue Date::Error
    nil
  end

  attr_reader :changements, :cas

  def initialize(opportunite)
    @o = opportunite
    @changements = {}
    @cas = Set.new
    convertir_chaines
    reconcilier(:starts_at, :starts_on, :start_time)
    reconcilier(:ends_at, :ends_on, :end_time)
    @cas << :permanente if valeur(:starts_on).nil? && valeur(:ends_on).nil?
  end

  private

  # Valeur après conversion : ce qu'on s'apprête à écrire, sinon ce qui est déjà en base.
  def valeur(colonne) = @changements.fetch(colonne) { en_base(colonne) }

  # nil si la colonne n'existe pas encore : le rapport peut tourner avant la migration.
  def en_base(colonne) = @o.respond_to?(colonne) ? @o.public_send(colonne) : nil

  def convertir_chaines
    libres = []
    { start_date: :starts_on, end_date: :ends_on }.each do |source, cible|
      texte = @o.public_send(source).to_s.strip
      next if texte.empty?

      if (date = self.class.date_iso(texte))
        @cas << :iso
        @changements[cible] = date if en_base(cible).nil?
      else
        libres << texte
      end
    end

    libres.uniq.each do |texte|
      horaire = valeur(:schedule_text).to_s.strip
      if horaire.empty?
        @changements[:schedule_text] = texte
        @cas << :texte_bascule
      elsif horaire == texte
        @cas << :texte_bascule # déjà basculé (rapport relancé après la migration)
      else
        @cas << :texte_conserve
      end
    end
  end

  def reconcilier(source, jour, heure)
    moment = @o.public_send(source)
    return if moment.nil? || !valeur(jour).nil?

    @cas << :reconcilie
    if moment.utc.seconds_since_midnight.zero?
      @changements[jour] = moment.utc.to_date
    else
      local = moment.in_time_zone(FUSEAU)
      @changements[jour] = local.to_date
      @changements[heure] = local.strftime("%H:%M") unless local.seconds_since_midnight.zero?
    end
  end
end
