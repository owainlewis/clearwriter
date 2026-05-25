class CreateCollectionDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_documents do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    # A document appears at most once in a given collection.
    add_index :collection_documents, [ :collection_id, :document_id ], unique: true
    add_index :collection_documents, [ :collection_id, :position ]
  end
end
