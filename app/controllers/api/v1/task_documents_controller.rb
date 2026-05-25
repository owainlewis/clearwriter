module Api
  module V1
    # Links a document to a task — the "agent produced a resource for this task"
    # path. Mirrors collection publishing: link an existing doc by id, or create
    # one from markdown and link it in a single call.
    #
    #   POST /api/v1/tasks/:task_id/documents
    #     { "document_id": "<token>" }   → link an existing doc
    #     { "body": "# Script..." }      → create the doc AND link it
    #
    #   DELETE /api/v1/tasks/:task_id/documents/:id   → unlink (:id = doc token)
    class TaskDocumentsController < BaseController
      before_action :set_task

      def create
        document =
          if params[:document_id].present?
            current_user.documents.find_by!(public_token: params[:document_id])
          elsif params[:body].present?
            current_user.documents.create!(document_create_params)
          else
            return render_error(:unprocessable_entity, "invalid",
                                "Provide either a document_id or a body to link")
          end

        @task.link_document(document)
        render status: :created, json: document_json(document)
      end

      def destroy
        document = current_user.documents.find_by!(public_token: params[:id])
        @task.unlink_document(document)
        head :no_content
      end

      private

      def set_task
        @task = current_user.tasks.find_by!(public_token: params[:task_id])
      end
    end
  end
end
