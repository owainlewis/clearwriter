class AddPinnedToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :pinned, :boolean, default: false, null: false
  end
end
