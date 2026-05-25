# Join row linking a Document to a Task. Documents live independently; a task
# just references the resources it relates to (e.g. the script an agent wrote).
class TaskDocument < ApplicationRecord
  belongs_to :task
  belongs_to :document

  validates :document_id, uniqueness: { scope: :task_id }
end
