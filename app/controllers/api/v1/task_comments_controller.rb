module Api
  module V1
    # Agents comment on a task via the API. Attribution is recorded as the
    # token's name so the human can see which agent said what.
    #
    #   POST /api/v1/tasks/:task_id/comments  { "body": "Draft is ready for review" }
    class TaskCommentsController < BaseController
      before_action :set_task

      def create
        comment = @task.task_comments.create!(
          body: params[:body],
          author_kind: "agent",
          author_name: @api_token.name.presence
        )
        render status: :created, json: {
          body: comment.body,
          author: comment.display_author,
          author_kind: comment.author_kind,
          created_at: comment.created_at
        }
      end

      private

      def set_task
        @task = current_user.tasks.find_by!(public_token: params[:task_id])
      end
    end
  end
end
