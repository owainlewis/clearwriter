class CreateTaskComments < ActiveRecord::Migration[8.1]
  def change
    create_table :task_comments do |t|
      t.references :task, null: false, foreign_key: true
      t.text :body, null: false, default: ""
      # Who wrote it: "human" (web, the owner) or "agent" (API token).
      t.string :author_kind, null: false, default: "human"
      # For agent comments, the API token's name (e.g. "hermes-vm").
      t.string :author_name

      t.timestamps
    end

    add_index :task_comments, [ :task_id, :created_at ]
  end
end
