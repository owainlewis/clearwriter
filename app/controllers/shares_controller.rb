class SharesController < ApplicationController
  before_action :set_document

  # POST /documents/:document_id/share
  def create
    @document.update!(is_public: true)
    redirect_to edit_document_path(@document), notice: "Share link enabled."
  end

  # DELETE /documents/:document_id/share
  def destroy
    @document.update!(is_public: false)
    redirect_to edit_document_path(@document), notice: "Share link disabled."
  end

  private

  def set_document
    @document = Current.user.documents.find_by!(public_token: params[:document_id])
  end
end
