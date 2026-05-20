module Api
  module V1
    class ContentsController < BaseController
      before_action :set_document

      # Content endpoints return text/plain on error so curl output is readable.
      def render_error(status, _code, message)
        render status: status, plain: message, content_type: "text/plain; charset=utf-8"
      end

      # GET /api/v1/documents/:document_id/content
      def show
        render plain: @document.body, content_type: "text/markdown; charset=utf-8"
      end

      # PUT /api/v1/documents/:document_id/content
      #
      # Accepts the raw markdown as the request body (Content-Type:
      # text/markdown). The whole body is replaced — no merge.
      def update
        raw = request.body.read
        @document.update!(body: raw.to_s)
        head :no_content
      end

      private

      def set_document
        @document = current_user.documents.find_by!(public_token: params[:document_id])
      end
    end
  end
end
