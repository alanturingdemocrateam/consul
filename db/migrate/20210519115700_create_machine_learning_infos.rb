class CreateMachineLearningInfos < ActiveRecord::Migration[5.2]
  def change
    create_table :machine_learning_infos do |t|
      t.datetime :kind
      t.datetime :generated_at
      t.string :script

      t.timestamps
    end
  end
end
