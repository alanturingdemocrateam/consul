class MlTagging < ApplicationRecord
  belongs_to :tagging, dependent: :destroy
end
