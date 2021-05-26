class MachineLearningInfo < ApplicationRecord
  class << self
    def for(kind)
      find_by(kind: kind)
    end

    def reset(kind)
      where(kind: kind).destroy_all
    end
  end
end
