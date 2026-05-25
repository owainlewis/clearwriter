# Manages collection membership from the web UI. The collection's documents
# come from the current user, so a user can only group their own docs.
class CollectionDocumentsController < ApplicationController
  before_action :set_collection

  def create
    document = Current.user.documents.find_by!(public_token: params[:document_id])
    @collection.add_document(document)
    redirect_to collection_path(@collection)
  end

  def destroy
    document = Current.user.documents.find_by!(public_token: params[:id])
    @collection.remove_document(document)
    redirect_to collection_path(@collection)
  end

  private

  def set_collection
    @collection = Current.user.collections.find_by!(public_token: params[:collection_id])
  end
end
