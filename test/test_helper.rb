ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Aucun test ne doit interroger Nominatim pour de vrai : lent, et un test qui
# dépend du réseau n'est pas rejouable. Le module `:test` fourni par le gem
# geocoder répond à partir de stubs déclarés par le test (`add_stub`), pas
# depuis le lookup réel configuré dans `config/initializers/geocoder.rb`.
Geocoder.configure(lookup: :test, ip_lookup: :test)

# Idem pour l'API Adresse (BAN) : par défaut elle « tombe en panne », donc repli sur la commune.
# Un test qui veut une adresse précise installe son faux client (voir AdresseBanTest).
class ClientBanIndisponible
  def get(*, **) = raise(Veille::Http::Error, "réseau coupé en test")
end
Veille::AdresseBan.client = ClientBanIndisponible.new
Veille::LieuOsm.client = ClientBanIndisponible.new # idem pour les noms de lieux (OSM)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Chaque test part sans stub hérité du précédent.
    teardown do
      Geocoder::Lookup::Test.reset
      Veille::AdresseBan.client = ClientBanIndisponible.new
      Veille::LieuOsm.client = ClientBanIndisponible.new
    end

    # Add more helper methods to be used by all tests here...
  end
end
