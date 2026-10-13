# frozen_string_literal: true

module Veille
  module Connectors
    # Un connecteur lit UNE source et rend des Veille::Item. #call ne lève
    # jamais : il rend un Resultat dont le statut dit si la source répond
    # (:ok), refuse l'accès robot (:refuse), est injoignable (:erreur) ou n'est
    # pas configurée (:inactive, p. ex. clé d'API absente).
    class Base
      Resultat = Struct.new(:nom, :statut, :items, :message, keyword_init: true)

      class NonConfigure < StandardError; end

      attr_reader :http, :today

      def initialize(http: Veille::Http.new, today: Date.current)
        @http  = http
        @today = today
      end

      def nom     = self.class.name.demodulize
      def origin  = raise(NotImplementedError)
      def collect = raise(NotImplementedError)

      def call
        items = collect
        Resultat.new(nom: nom, statut: :ok, items: items, message: "#{items.size} élément(s) retenu(s)")
      rescue Veille::Http::Refused => e
        Resultat.new(nom: nom, statut: :refuse, items: [], message: e.message)
      rescue NonConfigure => e
        Resultat.new(nom: nom, statut: :inactive, items: [], message: e.message)
      rescue StandardError => e
        Rails.logger.warn("[Veille] #{nom} : #{e.class} #{e.message}")
        Resultat.new(nom: nom, statut: :erreur, items: [], message: "#{e.class.name.demodulize} — #{e.message}".slice(0, 300))
      end

      private

      def json(url, **opts) = JSON.parse(http.get(url, **opts))

      def parse_date(valeur)
        valeur.present? ? Date.parse(valeur.to_s) : nil
      rescue Date::Error
        nil
      end
    end
  end
end
