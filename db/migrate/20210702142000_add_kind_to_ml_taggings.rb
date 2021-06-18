class AddKindToMlTaggings < ActiveRecord::Migration[5.2]
  def change
    add_column :ml_taggings, :kind, :string
  end
end
