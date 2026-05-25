module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_bearer_token

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable

      private

      def authenticate_bearer_token
        header = request.headers["Authorization"]
        raw = header.to_s.start_with?("Bearer ") ? header.split(" ", 2).last.to_s.strip : nil

        @api_token = ApiToken.authenticate(raw)
        return render_error(:unauthorized, "invalid_token", "Invalid or missing bearer token") unless @api_token

        @api_token.touch_last_used!
        @current_user = @api_token.user
      end

      def current_user
        @current_user
      end

      def not_found
        render_error(:not_found, "not_found", "Resource not found")
      end

      def unprocessable(exception)
        render_error(:unprocessable_entity, "invalid", exception.record.errors.full_messages.join(", "))
      end

      def render_error(status, code, message)
        # API errors are JSON by default. The content endpoints (text/markdown)
        # override this and return text/plain on error so curl output is readable —
        # see Api::V1::ContentsController.
        render status: status, json: { error: code, message: message }
      end

      # Shared document representation used by the documents and collections
      # endpoints. public_url is only present once a doc has been shared.
      def document_json(d)
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

      # Shared, safe params for creating a document from the API. Title is
      # always derived from the body server-side, so it's never accepted here.
      # Tags may arrive as a comma string (tags_text) or an array.
      def document_create_params
        permitted = params.permit(:body, :tags_text, tags: [])
        if permitted[:tags].is_a?(Array)
          permitted[:tags] = permitted[:tags].map { |t| t.to_s.strip.downcase }.reject(&:blank?).uniq
        end
        permitted
      end
    end
  end
end
