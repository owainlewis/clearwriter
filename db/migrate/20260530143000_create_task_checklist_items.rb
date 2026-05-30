class CreateTaskChecklistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :task_checklist_items do |t|
      t.references :task, null: false, foreign_key: true
      t.string :content, null: false, default: ""
      t.boolean :done, null: false, default: false
      t.integer :position, null: false, default: 0
      t.string :public_token, null: false
      t.timestamps
    end
    add_index :task_checklist_items, :public_token, unique: true
    add_index :task_checklist_items, [ :task_id, :position ]
  end
end
