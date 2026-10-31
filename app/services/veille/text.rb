# frozen_string_literal: true

module Veille
  # Normalisations de texte partagées par le dédoublonnage et la détection de commune.
  module Text
    module_function

    # « L'Été à Vandœuvre ! » → « l ete a vandoeuvre » : minuscules, sans accents
    # (œ → oe), ponctuation réduite à une espace.
    def normalize(texte)
      I18n.transliterate(texte.to_s.downcase.gsub("œ", "oe").gsub("æ", "ae"), replacement: " ")
          .gsub(/[^a-z0-9]+/, " ").squish
    end

    # Retire les balises et décode les entités ; rend un texte sur une ligne.
    def plain(html)
      Nokogiri::HTML.fragment(html.to_s).text.gsub(/[[:space:]]+/, " ").strip
    end

    def words(texte) = texte.to_s.scan(/[[:alnum:]'’\-]+/)

    # Citation maximale tolérée d'une source, en mots consécutifs.
    MAX_CITATION = 15

    # Vrai si `texte` reprend plus de `max` mots consécutifs de `source`
    # (comparaison sans accents ni ponctuation).
    def copie_excessive?(texte, source, max: MAX_CITATION)
      r = normalize(texte).split
      s = normalize(source).split
      return false if r.size <= max || s.size <= max

      fenetres = s.each_cons(max + 1).to_set
      r.each_cons(max + 1).any? { |f| fenetres.include?(f) }
    end
  end
end
