module Api
  module V1
    # Collection membership — and the agent publish path.
    #
    #   POST /api/v1/collections/:collection_id/documents
    #     { "document_id": "<token>" }  → attach an existing doc
    #     { "body": "# markdown..." }   → create a new doc and attach it
    #
    #   DELETE /api/v1/collections/:collection_id/documents/:id
    #     :id is the document's public_token → detach (the doc is not deleted)
    class CollectionDocumentsController < BaseController
      before_action :set_collection

      def create
        document =
          if params[:document_id].present?
            current_user.documents.find_by!(public_token: params[:document_id])
          elsif params[:body].present?
            current_user.documents.create!(document_create_params)
          else
            return render_error(:unprocessable_entity, "invalid",
                                "Provide either a document_id or a body to publish")
          end

        @collection.add_document(document)
        render status: :created, json: document_json(document)
      end

      def destroy
        document = current_user.documents.find_by!(public_token: params[:id])
        @collection.remove_document(document)
        head :no_content
      end

      private

      def set_collection
        @collection = current_user.collections.find_by!(public_token: params[:collection_id])
      end
    end
  end
end
