class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false, default: ""
      t.string :public_token, null: false

      t.timestamps
    end

    add_index :collections, :public_token, unique: true
    add_index :collections, [ :user_id, :updated_at ], order: { updated_at: :desc }
  end
end
