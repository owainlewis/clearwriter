# A unit of work on the board — typically something an AI agent does, with a
# human reviewing. Minimal by design: title + description + a fixed status.
# Resources (documents) are linked, not owned; comments form the activity log.
class Task < ApplicationRecord
  include HasPublicToken

  # Fixed kanban columns, in board order. The agent moves work toward Review;
  # the human approves into Done.
  STATUSES = %w[todo doing review done].freeze
  STATUS_LABELS = { "todo" => "Todo", "doing" => "Doing", "review" => "Review", "done" => "Done" }.freeze

  # Importance, P0 (most urgent) → none. Default none so nothing fakes urgency;
  # the value is in scarcity — only a few P0/P1 tasks should exist at once.
  PRIORITIES = %w[p0 p1 p2 p3 none].freeze
  PRIORITY_LABELS = { "p0" => "P0", "p1" => "P1", "p2" => "P2", "p3" => "P3", "none" => "None" }.freeze
  # Sort weight: lower comes first, so P0 rises and none sinks.
  PRIORITY_RANK = { "p0" => 0, "p1" => 1, "p2" => 2, "p3" => 3, "none" => 4 }.freeze

  TITLE_FALLBACK = "Untitled task"

  belongs_to :user
  has_many :task_comments, -> { order(:created_at) }, dependent: :destroy
  has_many :task_documents, dependent: :destroy
  has_many :documents, through: :task_documents
  # An ordered checklist agents tick off to verify each step is done.
  has_many :checklist_items, -> { order(:position, :created_at) },
           class_name: "TaskChecklistItem", dependent: :destroy

  normalizes :title, with: ->(t) { t.to_s.strip }

  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }

  before_validation :assign_default_position, on: :create

  scope :board_order, -> { order(:position, :created_at) }
  # Focus-first ordering for lists/API (not the kanban board, which stays
  # manually ordered by position): most important first, then most recent.
  scope :focus_order, -> { order(Arel.sql(priority_rank_sql), updated_at: :desc) }

  # CASE expression mapping the priority string to its sort weight. Built only
  # from the frozen PRIORITY_RANK constant — no user input — so it's injection-safe.
  def self.priority_rank_sql
    whens = PRIORITY_RANK.map { |value, rank| "WHEN '#{value}' THEN #{rank}" }.join(" ")
    "CASE priority #{whens} ELSE #{PRIORITY_RANK.values.max} END"
  end

  def display_title
    title.presence || TITLE_FALLBACK
  end

  # [done, total] for the checklist. Uses the loaded association so the show
  # page and turbo refreshes don't fire extra count queries.
  def checklist_progress
    items = checklist_items.to_a
    [ items.count(&:done), items.size ]
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
