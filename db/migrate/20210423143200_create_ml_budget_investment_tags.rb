class CreateMlBudgetInvestmentTags < ActiveRecord::Migration[5.2]
  def change
    create_table :ml_investment_tags do |t|
      t.string :name
      t.string :kind
      t.integer :ml_investment_taggings_count
      t.integer :budget_investments_count

      t.timestamps
    end

    create_table :ml_investment_taggings do |t|
      t.references :tag
      t.references :taggable, polymorphic: true
      t.references :tagger, polymorphic: true
      t.string :context, limit: 128

      t.timestamps
    end

    add_index :ml_investment_tags, :name, unique: true
    add_index :ml_investment_taggings, [:taggable_id, :taggable_type, :context],
              name: :ml_investments_taggings_taggable
  end
end
