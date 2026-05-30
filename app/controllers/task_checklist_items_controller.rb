class TaskChecklistItemsController < ApplicationController
  before_action :set_task

  def create
    content = params.dig(:task_checklist_item, :content).to_s
    @task.checklist_items.create!(content: content) if content.strip.present?
    respond_with_checklist
  end

  def update
    item = @task.checklist_items.find_by!(public_token: params[:id])
    item.update!(item_params)
    respond_with_checklist
  end

  def destroy
    item = @task.checklist_items.find_by!(public_token: params[:id])
    item.destroy!
    respond_with_checklist
  end

  private

    def set_task
      @task = Current.user.tasks.find_by!(public_token: params[:task_id])
    end

    def item_params
      params.require(:task_checklist_item).permit(:content, :done)
    end

    # The checklist is small, so re-rendering the whole section on each change
    # keeps the progress count, empty state, and rows perfectly in sync.
    def respond_with_checklist
      @task.checklist_items.reset
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("checklist",
            partial: "tasks/checklist", locals: { task: @task })
        end
        format.html { redirect_to task_path(@task) }
      end
    end
end
