class TasksController < ApplicationController
  before_action :set_task, only: %i[show update destroy]

  def index
    @tasks_by_status = Current.user.tasks
      .board_order
      .includes(:task_comments, :task_documents)
      .group_by(&:status)
  end

  def show
    @documents = @task.documents.order(updated_at: :desc)
    # Linkable documents are fetched on demand by the search picker
    # (see TaskDocumentsController#search).
  end

  def create
    task = Current.user.tasks.create!(task_create_params)
    # Quick-create (e.g. the "n t" shortcut) sends no title — open the new task
    # so it can be filled in. Board column adds carry a title and stay on the board.
    redirect_to task.title.blank? ? task_path(task) : tasks_path
  end

  def update
    @task.update!(task_update_params)
    redirect_to task_path(@task)
  end

  def destroy
    @task.destroy!
    redirect_to tasks_path, notice: "Task deleted."
  end

  # Drag-and-drop persistence. Receives the target column's status and the new
  # ordered list of task tokens; renumbers that column. Owner-scoped, so a
  # forged token simply isn't found and is skipped.
  def reorder
    status = params[:status].to_s
    return head :unprocessable_entity unless Task::STATUSES.include?(status)

    tasks = Current.user.tasks.where(public_token: Array(params[:ids])).index_by(&:public_token)
    Array(params[:ids]).each_with_index do |token, index|
      tasks[token]&.update_columns(status: status, position: index, updated_at: Time.current)
    end
    head :no_content
  end

  private

  def set_task
    @task = Current.user.tasks.find_by!(public_token: params[:id])
  end

  def task_create_params
    permitted = params.expect(task: [ :title, :status, :priority ])
    permitted.delete(:status) unless Task::STATUSES.include?(permitted[:status])
    permitted.delete(:priority) unless Task::PRIORITIES.include?(permitted[:priority])
    permitted
  end

  def task_update_params
    permitted = params.expect(task: [ :title, :description, :status, :priority ])
    permitted.delete(:status) unless Task::STATUSES.include?(permitted[:status])
    permitted.delete(:priority) unless Task::PRIORITIES.include?(permitted[:priority])
    permitted
  end
end
