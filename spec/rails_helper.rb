require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__) # Prevent database truncation in production. Local? Try RAILS_ENV=test
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
# Add additional requires below this line. Rails is not loaded until this point!
require "pundit/rspec"
require "webdrivers" unless ENV["DOCKER"]

# Require all support folder files
Dir[Rails.root.join("spec", "support", "**", "*.rb")].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  config.include DatatableHelper, type: :datatable
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include Organizational, type: :helper
  config.include Organizational, type: :view
  config.include PunditHelper, type: :view
  config.include SessionHelper, type: :view
  config.include SessionHelper, type: :request
  config.include Warden::Test::Helpers
  config.include WordDocHelper, type: :model
  config.include WordDocHelper, type: :request

  config.after do
    Warden.test_reset!
  end

  Shoulda::Matchers.configure do |shoulda_config|
    shoulda_config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end

  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.use_transactional_fixtures = true

  config.infer_spec_type_from_file_location!

  # Auto detect datatable type specs
  config.define_derived_metadata(file_path: Regexp.new("/spec/datatables/")) do |metadata|
    metadata[:type] = :datatable
  end

  config.example_status_persistence_file_path = "#{::Rails.root}/tmp/persistent_examples.txt"

  config.filter_rails_from_backtrace!

  config.disable_monkey_patching!

  if Bullet.enable?
    unless ENV["SKIP_BULLET"]
      config.before do
        Bullet.start_request
      end
      config.after do
        Bullet.perform_out_of_channel_notifications if Bullet.notification?
        Bullet.end_request
      end
    end
  end
  config.around :each, :disable_bullet do |example|
    Bullet.raise = false
    example.run
    Bullet.raise = true
  end
end
