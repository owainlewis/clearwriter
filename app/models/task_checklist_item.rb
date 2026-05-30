class TaskChecklistItem < ApplicationRecord
  include HasPublicToken

  belongs_to :task

  normalizes :content, with: ->(c) { c.to_s.strip }
  validates :content, presence: true

  before_validation :assign_default_position, on: :create

  scope :ordered, -> { order(:position, :created_at) }

  private

    # Append to the end of the task's checklist.
    def assign_default_position
      self.position = (task&.checklist_items&.maximum(:position) || -1) + 1
    end
end
