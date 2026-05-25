# A unit of work on the board — typically something an AI agent does, with a
# human reviewing. Minimal by design: title + description + a fixed status.
# Resources (documents) are linked, not owned; comments form the activity log.
class Task < ApplicationRecord
  include HasPublicToken

  # Fixed kanban columns, in board order. The agent moves work toward Review;
  # the human approves into Done.
  STATUSES = %w[todo doing review done].freeze
  STATUS_LABELS = { "todo" => "Todo", "doing" => "Doing", "review" => "Review", "done" => "Done" }.freeze

  TITLE_FALLBACK = "Untitled task"

  belongs_to :user
  has_many :task_comments, -> { order(:created_at) }, dependent: :destroy
  has_many :task_documents, dependent: :destroy
  has_many :documents, through: :task_documents

  normalizes :title, with: ->(t) { t.to_s.strip }

  validates :status, inclusion: { in: STATUSES }

  before_validation :assign_default_position, on: :create

  scope :board_order, -> { order(:position, :created_at) }

  def display_title
    title.presence || TITLE_FALLBACK
  end

  # Links a document to this task (idempotent).
  def link_document(document)
    task_documents.find_or_create_by!(document: document)
  end

  def unlink_document(document)
    task_documents.where(document: document).destroy_all
  end

  private

  # New tasks land at the end of their column.
  def assign_default_position
    self.position ||= 0
    return unless position.zero?

    self.position = (user&.tasks&.where(status: status)&.maximum(:position) || -1) + 1
  end
end
