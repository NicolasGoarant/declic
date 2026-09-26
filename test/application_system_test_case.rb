require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # CHROME_BIN : chemin d'un Chrome/Chromium quand il n'est pas à l'emplacement habituel.
  # CHROME_NO_SANDBOX=1 : là où le bac à sable de Chrome est refusé (conteneur, AppArmor).
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    options.add_argument("--no-sandbox") if ENV["CHROME_NO_SANDBOX"].present?
  end
end
