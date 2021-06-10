class MlTag < ApplicationRecord
  belongs_to :tag, dependent: :destroy
end
