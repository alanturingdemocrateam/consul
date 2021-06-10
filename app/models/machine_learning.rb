class MachineLearning
  attr_reader :user, :script, :previous_modified_date
  attr_accessor :job

  SCRIPTS_FOLDER = Rails.root.join("public", "machine_learning", "scripts").freeze
  DATA_FOLDER = Rails.root.join("public", "machine_learning", "data").freeze

  def initialize(job)
    @job = job
    @user = job.user
    @script = SCRIPTS_FOLDER.join(job.script)
    @previous_modified_date = set_previous_modified_date
  end

  def run
    begin
      export_proposals_to_json
      export_budget_investments_to_json
      export_comments_to_json

      return unless run_machine_learning_scripts

      if updated_file?(MachineLearning.taggins_filename) && updated_file?(MachineLearning.tags_filename)
        cleanup_tags!
        import_ml_tags
        import_ml_taggins
        update_machine_learning_info_for("tags")
      end

      if updated_file?(MachineLearning.proposals_related_filename)
        cleanup_proposals_related_content!
        import_proposals_related_content
        update_machine_learning_info_for("related_content")
      end

      if updated_file?(MachineLearning.investments_related_filename)
        cleanup_investments_related_content!
        import_budget_investments_related_content
        update_machine_learning_info_for("related_content")
      end

      if updated_file?(MachineLearning.comments_summary_filename)
        cleanup_comments_summary!
        import_ml_comments_summary
        update_machine_learning_info_for("comments_summary")
      end

      job.update!(finished_at: Time.current)
      Mailer.machine_learning_success(user).deliver_later
    rescue Exception => error
      handle_error(error)
      raise error
    end
  end
  handle_asynchronously :run, queue: "machine_learning"

  class << self
    def proposals_filename
      "proposals.json"
    end

    def investments_filename
      "budget_investments.json"
    end

    def comments_filename
      "comments.json"
    end

    def data_output_files
      files = { tags: [], related_content: [], comments_summary: [] }

      files[:tags] << tags_filename if File.exists?(DATA_FOLDER.join(tags_filename))
      files[:tags] << taggins_filename if File.exists?(DATA_FOLDER.join(taggins_filename))
      files[:related_content] << proposals_related_filename if File.exists?(DATA_FOLDER.join(proposals_related_filename))
      files[:related_content] << investments_related_filename if File.exists?(DATA_FOLDER.join(investments_related_filename))
      files[:comments_summary] << comments_summary_filename if File.exists?(DATA_FOLDER.join(comments_summary_filename))

      files
    end

    def tags_filename
      "ml_tags.json"
    end

    def taggins_filename
      "ml_taggings.json"
    end

    def proposals_related_filename
      "ml_relat_props.json"
    end

    def investments_related_filename
      "ml_relat_invs.json"
    end

    def comments_summary_filename
      "ml_comments_summaries.json"
    end

    def data_path(filename)
      "/machine_learning/data/" + filename
    end

    def script_kinds
      %w[tags related_content comments_summary]
    end
  end

  private

    def export_proposals_to_json
      filename = DATA_FOLDER.join(MachineLearning.proposals_filename)
      Proposal::Exporter.new.to_json_file(filename)
    end

    def export_budget_investments_to_json
      filename = DATA_FOLDER.join(MachineLearning.investments_filename)
      Budget::Investment::Exporter.new(Array.new).to_json_file(filename)
    end

    def export_comments_to_json
      filename = DATA_FOLDER.join(MachineLearning.comments_filename)
      Comment::Exporter.new.to_json_file(filename)
    end

    def run_machine_learning_scripts
      output = `python #{script} 2>&1`
      result = $?.success?
      if result == false
        job.update!(finished_at: Time.current, error: output)
        Mailer.machine_learning_error(user).deliver_later
      end
      result
    end

    def cleanup_tags!
      MlTagging.destroy_all
      MlTag.destroy_all
    end

    def cleanup_proposals_related_content!
      RelatedContent.with_hidden.for_proposals.from_machine_learning.each(&:really_destroy!)
    end

    def cleanup_investments_related_content!
      RelatedContent.with_hidden.for_investments.from_machine_learning.each(&:really_destroy!)
    end

    def cleanup_comments_summary!
      MlSummaryComment.destroy_all
    end

    def import_ml_comments_summary
      json_file = DATA_FOLDER.join(MachineLearning.comments_summary_filename)
      json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
      json_data.each do |attributes|
        attributes.delete(:id)
        unless MlSummaryComment.find_by(commentable_id: attributes[:commentable_id],
                                        commentable_type: attributes[:commentable_type])
          MlSummaryComment.create!(attributes)
        end
      end
    end

    def import_proposals_related_content
      json_file = DATA_FOLDER.join(MachineLearning.proposals_related_filename)
      json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
      json_data.each do |related|
        id = related.delete(:id)
        related.each do |_, related_id|
          if related_id.present?
            attributes = {
              parent_relationable_id: id,
              parent_relationable_type: "Proposal",
              child_relationable_id: related_id,
              child_relationable_type: "Proposal"
            }
            unless RelatedContent.find_by(attributes)
              RelatedContent.create!(attributes.merge(machine_learning: true, author: user))
            end
          end
        end
      end
    end

    def import_budget_investments_related_content
      json_file = DATA_FOLDER.join(MachineLearning.investments_related_filename)
      json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
      json_data.each do |related|
        id = related.delete(:id)
        related.each do |_, related_id|
          if related_id.present?
            attributes = {
              parent_relationable_id: id,
              parent_relationable_type: "Budget::Investment",
              child_relationable_id: related_id,
              child_relationable_type: "Budget::Investment"
            }
            unless RelatedContent.find_by(attributes)
              RelatedContent.create!(attributes.merge(machine_learning: true, author: user))
            end
          end
        end
      end
    end

    def import_ml_tags
      json_file = DATA_FOLDER.join(MachineLearning.tags_filename)
      json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
      json_data.each do |attributes|
        ml_tag_id = attributes.delete(:id)
        if attributes[:name].present?
          if attributes[:name].length >= 150
            attributes[:name] = attributes[:name].truncate(150)
          end
          tag = Tag.find_by(name: attributes[:name])
          tag = Tag.create!(attributes) unless tag.present?
          MlTag.create!(id: ml_tag_id, tag: tag) unless MlTag.find_by(tag_id: tag.id).present?
        end
      end
    end

    def import_ml_taggins
      json_file = DATA_FOLDER.join(MachineLearning.taggins_filename)
      json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
      json_data.each do |attributes|
        ml_tag_id = attributes[:tag_id]
        if MlTag.find_by(id: ml_tag_id).present?
          attributes[:tag_id] = MlTag.find(ml_tag_id).tag_id
          attributes[:context] = "tags"
          if Tag.find_by(id: attributes[:tag_id])
            if attributes[:taggable_id].present? && attributes[:taggable_type].present?
              unless Tagging.find_by(tag_id: attributes[:tag_id],
                                     taggable_id: attributes[:taggable_id],
                                     taggable_type: attributes[:taggable_type])
                tagging = Tagging.create!(attributes)
                MlTagging.create!(tagging: tagging)
              end
            end
          end
        end
      end
    end

    def update_machine_learning_info_for(kind)
      MachineLearningInfo.find_or_create_by!(kind: kind)
                         .update!(generated_at: Time.current, script: job.script)
    end

    def set_previous_modified_date
      tags_filename = MachineLearning.tags_filename
      taggins_filename = MachineLearning.taggins_filename
      proposals_related_filename = MachineLearning.proposals_related_filename
      investments_related_filename = MachineLearning.investments_related_filename
      comments_summary_filename = MachineLearning.comments_summary_filename

      {
        tags_filename => last_modified_date_for(tags_filename),
        taggins_filename => last_modified_date_for(taggins_filename),
        proposals_related_filename => last_modified_date_for(proposals_related_filename),
        investments_related_filename => last_modified_date_for(investments_related_filename),
        comments_summary_filename => last_modified_date_for(comments_summary_filename)
      }
    end

    def last_modified_date_for(filename)
      return nil unless File.exists? DATA_FOLDER.join(filename)

      File.mtime DATA_FOLDER.join(filename)
    end

    def updated_file?(filename)
      return false unless File.exists? DATA_FOLDER.join(filename)
      return true unless previous_modified_date[filename].present?

      last_modified_date_for(filename) > previous_modified_date[filename]
    end

    def handle_error(error)
      message = error.message
      backtrace = error.backtrace.select { |line| line.include?("machine_learning.rb") }
      full_error = ([message] + backtrace).join("<br>")
      job.update!(finished_at: Time.current, error: full_error)
      Mailer.machine_learning_error(user).deliver_later
    end
end
