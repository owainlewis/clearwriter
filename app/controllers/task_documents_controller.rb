# Links / unlinks a document to a task from the web UI via a search-driven
# picker. Documents stay independent — this only manages the reference, and
# changes stream back in place (Turbo) without a page reload.
class TaskDocumentsController < ApplicationController
  before_action :set_task

  def search
    render partial: "shared/document_results",
           locals: { documents: linkable_documents, link_url: task_documents_path(@task) }
  end

  def create
    document = Current.user.documents.find_by!(public_token: params[:document_id])
    @task.link_document(document)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("linked-docs", partial: "shared/linked_document",
            locals: { document: document, unlink_url: task_document_path(@task, document) }),
          turbo_stream.remove("result-#{document.public_token}"),
          turbo_stream.remove("linked-docs-empty")
        ]
      end
      format.html { redirect_to task_path(@task) }
    end
  end

  def destroy
    document = Current.user.documents.find_by!(public_token: params[:id])
    @task.unlink_document(document)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("linked-doc-#{document.public_token}") }
      format.html { redirect_to task_path(@task) }
    end
  end

  private

  def set_task
    @task = Current.user.tasks.find_by!(public_token: params[:task_id])
  end

  def linkable_documents
    scope = Current.user.documents.where.not(id: @task.document_ids)
    scope = scope.search(params[:q]) if params[:q].present?
    scope.order(updated_at: :desc).limit(8)
  end
end
