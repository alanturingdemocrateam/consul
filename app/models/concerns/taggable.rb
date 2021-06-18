module Taggable
  extend ActiveSupport::Concern

  included do
    acts_as_taggable
    validate :max_number_of_tags, on: :create
  end

  def tags_list
    if Setting["machine_learning.tags"]
      tags.where(id: MlTag.pluck(:tag_id))
    else
      tags.where.not(id: MlTag.pluck(:tag_id))
    end
  end

  def tag_list_with_limit(limit = nil)
    return tags_list if limit.blank?

    tags_list.sort { |a, b| b.taggings_count <=> a.taggings_count }[0, limit]
  end

  def max_number_of_tags
    errors.add(:tag_list, :less_than_or_equal_to, count: 6) if tag_list.count > 6
  end
end
