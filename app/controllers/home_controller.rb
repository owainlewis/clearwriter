class HomeController < ApplicationController
  def index
    # Signed-in: send to the documents list.
    # Signed-out: Authentication concern already redirects to /sign_in.
    # The signed-out landing page lands in #14.
    redirect_to documents_path
  end
end
