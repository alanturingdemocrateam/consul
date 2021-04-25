class CreateMlTaggings < ActiveRecord::Migration[5.2]
  def change
    create_table :ml_taggings do |t|
      t.references :tagging, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
