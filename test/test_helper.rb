ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Aucun test ne doit interroger Nominatim pour de vrai : lent, et un test qui
# dépend du réseau n'est pas rejouable. Le module `:test` fourni par le gem
# geocoder répond à partir de stubs déclarés par le test (`add_stub`), pas
# depuis le lookup réel configuré dans `config/initializers/geocoder.rb`.
Geocoder.configure(lookup: :test, ip_lookup: :test)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Chaque test part sans stub hérité du précédent.
    teardown { Geocoder::Lookup::Test.reset }

    # Add more helper methods to be used by all tests here...
  end
end
