class CreateMlTags < ActiveRecord::Migration[5.2]
  def change
    create_table :ml_tags do |t|
      t.references :tag, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
