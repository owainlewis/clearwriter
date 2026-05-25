module Api
  module V1
    class CollectionsController < BaseController
      before_action :set_collection, only: %i[show update destroy]

      def index
        render json: current_user.collections.ordered.map { |c| collection_json(c) }
      end

      def show
        render json: collection_json(@collection, include_documents: true)
      end

      def create
        collection = current_user.collections.create!(collection_params)
        render status: :created, json: collection_json(collection)
      end

      def update
        @collection.update!(collection_params)
        render json: collection_json(@collection)
      end

      def destroy
        @collection.destroy!
        head :no_content
      end

      private

      def set_collection
        @collection = current_user.collections.find_by!(public_token: params[:id])
      end

      def collection_json(c, include_documents: false)
        json = {
          id: c.public_token,
          name: c.name,
          document_count: c.documents.size,
          updated_at: c.updated_at,
          created_at: c.created_at
        }
        json[:documents] = c.documents.map { |d| document_json(d) } if include_documents
        json
      end

      def collection_params
        params.permit(:name)
      end
    end
  end
end
