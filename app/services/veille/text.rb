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
  end
end
