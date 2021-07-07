class CreateMlProposalTags < ActiveRecord::Migration[5.2]
  def change
    create_table :ml_proposal_tags do |t|
      t.string :name
      t.string :kind
      t.integer :ml_proposal_taggings_count
      t.integer :proposals_count

      t.timestamps
    end

    create_table :ml_proposal_taggings do |t|
      t.references :tag
      t.references :taggable, polymorphic: true
      t.references :tagger, polymorphic: true
      t.string :context, limit: 128

      t.timestamps
    end

    add_index :ml_proposal_tags, :name, unique: true
    add_index :ml_proposal_taggings, [:taggable_id, :taggable_type, :context],
              name: :ml_proposal_taggings_taggable
  end
end
