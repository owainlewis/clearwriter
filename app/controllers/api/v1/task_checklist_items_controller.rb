module Api
  module V1
    # Agents manage a task's checklist to verify their work step by step.
    #
    #   GET    /api/v1/tasks/:task_id/checklist_items
    #   POST   /api/v1/tasks/:task_id/checklist_items      { "content": "Write the intro" }
    #   PATCH  /api/v1/tasks/:task_id/checklist_items/:id   { "done": true }
    #   DELETE /api/v1/tasks/:task_id/checklist_items/:id
    class TaskChecklistItemsController < BaseController
      before_action :set_task

      def index
        render json: @task.checklist_items.map { |i| checklist_item_json(i) }
      end

      def create
        item = @task.checklist_items.create!(content: params[:content], done: params.fetch(:done, false))
        render status: :created, json: checklist_item_json(item)
      end

      def update
        item = @task.checklist_items.find_by!(public_token: params[:id])
        item.update!(params.permit(:content, :done))
        render json: checklist_item_json(item)
      end

      def destroy
        item = @task.checklist_items.find_by!(public_token: params[:id])
        item.destroy!
        head :no_content
      end

      private

        def set_task
          @task = current_user.tasks.find_by!(public_token: params[:task_id])
        end

        def checklist_item_json(item)
          {
            id: item.public_token,
            content: item.content,
            done: item.done,
            position: item.position
          }
        end
    end
  end
end
