class PinsController < ApplicationController
  before_action :set_document

  # POST /documents/:document_id/pin
  def create
    @document.update!(pinned: true)
    redirect_back fallback_location: documents_path
  end

  # DELETE /documents/:document_id/pin
  def destroy
    @document.update!(pinned: false)
    redirect_back fallback_location: documents_path
  end

  private

  def set_document
    @document = Current.user.documents.find_by!(public_token: params[:document_id])
  end
end
