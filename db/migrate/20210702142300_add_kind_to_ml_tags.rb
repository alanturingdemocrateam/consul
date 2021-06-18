class AddKindToMlTags < ActiveRecord::Migration[5.2]
  def change
    add_column :ml_tags, :kind, :string
  end
end
