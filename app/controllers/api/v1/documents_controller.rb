module Api
  module V1
    class DocumentsController < BaseController
      before_action :set_document, only: %i[show update destroy]

      def index
        scope = current_user.documents.order(updated_at: :desc)
        scope = scope.with_tag(params[:tag]) if params[:tag].present?
        scope = scope.updated_since(parse_since(params[:since])) if parse_since(params[:since])

        render json: scope.map { |d| serialize(d) }
      end

      def show
        render json: serialize(@document)
      end

      def create
        document = current_user.documents.create!(document_params_safe)
        render status: :created, json: serialize(document)
      end

      def update
        @document.update!(document_params_safe)
        render json: serialize(@document)
      end

      def destroy
        @document.destroy!
        head :no_content
      end

      private

      def set_document
        @document = current_user.documents.find_by!(public_token: params[:id])
      end

      def serialize(d)
        {
          id: d.public_token,
          title: d.title,
          tags: d.tags,
          is_public: d.is_public,
          public_url: d.is_public ? Rails.application.routes.url_helpers.public_document_url(d.public_token, host: request.host_with_port, protocol: request.protocol) : nil,
          updated_at: d.updated_at,
          created_at: d.created_at
        }
      end

      def document_params_safe
        # JSON or form-encoded both accepted. Tags can be a comma string or array.
        permitted = params.permit(:title, :body, :tags_text, tags: [])
        if permitted[:tags].is_a?(Array)
          permitted[:tags] = permitted[:tags].map { |t| t.to_s.strip.downcase }.reject(&:blank?).uniq
        end
        permitted
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
