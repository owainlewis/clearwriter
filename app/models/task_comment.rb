# An entry in a task's activity log. Written by the human (via the web) or by
# an agent (via the API) — author_kind distinguishes them so the UI can badge
# agent activity. author_name carries the agent's token name when applicable.
class TaskComment < ApplicationRecord
  KINDS = %w[human agent].freeze

  belongs_to :task

  validates :body, presence: true
  validates :author_kind, inclusion: { in: KINDS }

  def agent?
    author_kind == "agent"
  end

  def display_author
    return "You" unless agent?

    author_name.presence || "Agent"
  end
end
