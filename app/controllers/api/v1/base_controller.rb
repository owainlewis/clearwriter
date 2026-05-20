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
    end
  end
end
