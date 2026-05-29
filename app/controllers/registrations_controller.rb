class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: "Sign ups are currently closed." }

  def new
    redirect_to new_session_path, alert: "Sign ups are currently closed."
  end

  def create
    redirect_to new_session_path, alert: "Sign ups are currently closed."
  end
end
