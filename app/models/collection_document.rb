# Join row linking a Document into a Collection at an ordered position.
class CollectionDocument < ApplicationRecord
  belongs_to :collection
  belongs_to :document

  validates :document_id, uniqueness: { scope: :collection_id }
end
