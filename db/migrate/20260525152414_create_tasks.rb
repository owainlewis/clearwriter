class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false, default: ""
      t.text :description, null: false, default: ""
      t.string :status, null: false, default: "todo"
      t.integer :position, null: false, default: 0
      t.string :public_token, null: false

      t.timestamps
    end

    add_index :tasks, :public_token, unique: true
    # Ordering within a column is per-(user, status, position).
    add_index :tasks, [ :user_id, :status, :position ]
  end
end
