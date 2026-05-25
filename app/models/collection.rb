# A virtual folder: a named, ordered grouping that references documents.
# Collections and documents have independent lifecycles — deleting a
# collection removes only its membership rows, never the documents
# themselves (and vice versa via Document#collection_documents).
class Collection < ApplicationRecord
  include HasPublicToken

  NAME_FALLBACK = "Untitled collection"

  belongs_to :user
  has_many :collection_documents, -> { order(:position) }, dependent: :destroy
  has_many :documents, through: :collection_documents

  normalizes :name, with: ->(n) { n.to_s.strip }

  scope :ordered, -> { order(updated_at: :desc) }

  def display_name
    name.presence || NAME_FALLBACK
  end

  # Adds a document at the end of the collection. Idempotent — re-adding an
  # existing member is a no-op rather than an error.
  def add_document(document)
    collection_documents.find_or_create_by!(document: document) do |cd|
      cd.position = next_position
    end
  end

  def remove_document(document)
    collection_documents.where(document: document).destroy_all
  end

  private

  def next_position
    (collection_documents.maximum(:position) || -1) + 1
  end
end
