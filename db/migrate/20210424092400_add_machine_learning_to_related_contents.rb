class AddMachineLearningToRelatedContents < ActiveRecord::Migration[5.2]
  def change
    add_column :related_contents, :machine_learning, :boolean, default: false
  end
end
