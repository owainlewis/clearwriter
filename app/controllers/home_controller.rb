class HomeController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    redirect_to documents_path if authenticated?
  end
end
