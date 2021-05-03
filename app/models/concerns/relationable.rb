module Relationable
  extend ActiveSupport::Concern

  included do
    has_many :related_contents,
      as:         :parent_relationable,
      inverse_of: :parent_relationable,
      dependent:  :destroy
  end

  def find_related_content(relationable)
    RelatedContent.find_by(parent_relationable: self, child_relationable: relationable)
  end

  def relationed_contents
    related_content = related_contents.not_hidden
    related_content = related_content.from_users unless Setting["machine_learning.related_content"]
    related_content.map(&:child_relationable).reject do |related|
      related.respond_to?(:retired?) && related.retired?
    end
  end
end
