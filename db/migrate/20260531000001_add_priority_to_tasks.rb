class AddPriorityToTasks < ActiveRecord::Migration[8.1]
  def change
    # default backfills existing rows to "none"; not null keeps sorting simple.
    add_column :tasks, :priority, :string, default: "none", null: false
  end
end
