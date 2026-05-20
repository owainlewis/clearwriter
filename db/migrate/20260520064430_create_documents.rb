class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false, default: ""
      t.text :body, null: false, default: ""
      t.string :tags, array: true, null: false, default: []
      t.string :public_token, null: false
      t.boolean :is_public, null: false, default: false

      t.timestamps
    end

    add_index :documents, :public_token, unique: true
    add_index :documents, [ :user_id, :updated_at ], order: { updated_at: :desc }
    add_index :documents, [ :user_id, :created_at ], order: { created_at: :desc }
    add_index :documents, :tags, using: :gin
  end
end
