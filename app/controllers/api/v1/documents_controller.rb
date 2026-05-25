module Api
  module V1
    class DocumentsController < BaseController
      before_action :set_document, only: %i[show update destroy]

      def index
        scope = current_user.documents.order(updated_at: :desc)
        scope = scope.search(params[:q]) if params[:q].present?
        scope = scope.with_tag(params[:tag]) if params[:tag].present?
        scope = scope.updated_since(parse_since(params[:since])) if parse_since(params[:since])

        render json: scope.map { |d| document_json(d) }
      end

      def show
        render json: document_json(@document)
      end

      def create
        document = current_user.documents.create!(document_create_params)
        render status: :created, json: document_json(document)
      end

      def update
        @document.update!(document_create_params)
        render json: document_json(@document)
      end

      def destroy
        @document.destroy!
        head :no_content
      end

      private

      def set_document
        @document = current_user.documents.find_by!(public_token: params[:id])
      end

      def parse_since(value)
        case value
        when nil, "", "all" then nil
        when /\A(\d+)d\z/ then Regexp.last_match(1).to_i.days.ago
        end
      end
    end
  end
end
