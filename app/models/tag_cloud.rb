class TagCloud
  attr_accessor :resource_model, :scope

  def initialize(resource_model, scope = nil)
    @resource_model = resource_model
    @scope = scope
  end

  def tags
    cloud_tags = resource_model_scoped.last_week.tag_counts.
                     where("lower(name) NOT IN (?)", category_names + geozone_names + default_blacklist)
    if Setting["machine_learning.tags"]
      cloud_tags = cloud_tags.where(id: ml_tags)
    else
      cloud_tags = cloud_tags.where.not(id: ml_tags)
    end
    cloud_tags.order("#{table_name}_count": :desc, name: :asc).limit(10)
  end

  def category_names
    Tag.category_names.map(&:downcase)
  end

  def geozone_names
    Geozone.all.map { |geozone| geozone.name.downcase }
  end

  def ml_tags
    MlTag.pluck(:tag_id)
  end

  def resource_model_scoped
    scope && resource_model == Proposal ? resource_model.search(scope) : resource_model
  end

  def default_blacklist
    [""]
  end

  def table_name
    resource_model.to_s.tableize.tr("/", "_")
  end
end
