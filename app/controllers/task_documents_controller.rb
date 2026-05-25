# Links / unlinks a document to a task from the web UI. Documents stay
# independent — this only manages the reference.
class TaskDocumentsController < ApplicationController
  before_action :set_task

  def create
    document = Current.user.documents.find_by!(public_token: params[:document_id])
    @task.link_document(document)
    redirect_to task_path(@task)
  end

  def destroy
    document = Current.user.documents.find_by!(public_token: params[:id])
    @task.unlink_document(document)
    redirect_to task_path(@task)
  end

  private

  def set_task
    @task = Current.user.tasks.find_by!(public_token: params[:task_id])
  end
end
