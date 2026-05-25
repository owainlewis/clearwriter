# Human comments on a task, posted from the task detail page.
class TaskCommentsController < ApplicationController
  def create
    task = Current.user.tasks.find_by!(public_token: params[:task_id])
    body = params.dig(:task_comment, :body).to_s
    task.task_comments.create!(body: body, author_kind: "human") if body.strip.present?
    redirect_to task_path(task)
  end
end
