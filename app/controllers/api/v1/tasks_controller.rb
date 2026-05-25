module Api
  module V1
    class TasksController < BaseController
      before_action :set_task, only: %i[show update destroy]

      def index
        scope = current_user.tasks.order(:status, :position, :created_at)
        scope = scope.where(status: params[:status]) if Task::STATUSES.include?(params[:status])
        render json: scope.map { |t| task_json(t) }
      end

      def show
        render json: task_json(@task, detail: true)
      end

      def create
        task = current_user.tasks.create!(task_params)
        render status: :created, json: task_json(task)
      end

      def update
        @task.update!(task_params)
        render json: task_json(@task)
      end

      def destroy
        @task.destroy!
        head :no_content
      end

      private

      def set_task
        @task = current_user.tasks.find_by!(public_token: params[:id])
      end

      def task_params
        permitted = params.permit(:title, :description, :status)
        permitted.delete(:status) unless Task::STATUSES.include?(permitted[:status])
        permitted
      end

      def task_json(task, detail: false)
        json = {
          id: task.public_token,
          title: task.title,
          status: task.status,
          description: task.description,
          updated_at: task.updated_at,
          created_at: task.created_at
        }
        if detail
          json[:comments] = task.task_comments.map { |c| comment_json(c) }
          json[:documents] = task.documents.map { |d| document_json(d) }
        end
        json
      end

      def comment_json(comment)
        {
          body: comment.body,
          author: comment.display_author,
          author_kind: comment.author_kind,
          created_at: comment.created_at
        }
      end
    end
  end
end
