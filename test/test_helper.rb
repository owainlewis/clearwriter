ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all

    # Posts to the real sign-in endpoint so the signed session cookie gets
    # written by the production code path. Test fixtures use the password
    # "password123" for every user.
    def sign_in_as(user, password: "password123")
      post session_path, params: { email_address: user.email_address, password: password }
      raise "sign_in_as failed for #{user.email_address}" unless cookies[:session_id].present?
      user
    end
  end
end
