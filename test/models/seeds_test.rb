require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "db/seeds.rb refuse de tourner en production sans SEED_ALLOW_DESTROY=oui" do
    ancien = ENV.delete("SEED_ALLOW_DESTROY")
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
      assert_no_difference -> { Story.count + Opportunity.count } do
        erreur = nil
        capture_io { erreur = assert_raises(SystemExit) { load Rails.root.join("db/seeds.rb") } }
        assert_not erreur.success?
      end
    end
  ensure
    ENV["SEED_ALLOW_DESTROY"] = ancien
  end
end
