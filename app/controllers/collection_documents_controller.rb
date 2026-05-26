# Manages collection membership from the web UI via a search-driven picker.
# Linking/unlinking stream back in place (Turbo) so the page never reloads.
class CollectionDocumentsController < ApplicationController
  before_action :set_collection

  # Typeahead results: the user's documents not already in this collection,
  # filtered by the query. Rendered as a fragment into the picker menu.
  def search
    render partial: "shared/document_results",
           locals: { documents: linkable_documents, link_url: collection_documents_path(@collection) }
  end

  def create
    document = Current.user.documents.find_by!(public_token: params[:document_id])
    @collection.add_document(document)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("linked-docs", partial: "shared/linked_document",
            locals: { document: document, unlink_url: collection_document_path(@collection, document) }),
          turbo_stream.remove("result-#{document.public_token}"),
          turbo_stream.remove("linked-docs-empty")
        ]
      end
      format.html { redirect_to collection_path(@collection) }
    end
  end

  def destroy
    document = Current.user.documents.find_by!(public_token: params[:id])
    @collection.remove_document(document)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("linked-doc-#{document.public_token}") }
      format.html { redirect_to collection_path(@collection) }
    end
  end

  private

  def set_collection
    @collection = Current.user.collections.find_by!(public_token: params[:collection_id])
  end

  def linkable_documents
    scope = Current.user.documents.where.not(id: @collection.document_ids)
    scope = scope.search(params[:q]) if params[:q].present?
    scope.order(updated_at: :desc).limit(8)
  end
end
