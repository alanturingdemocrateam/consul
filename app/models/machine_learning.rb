class MachineLearning
  attr_reader :user, :script, :kind
  attr_accessor :job

  SCRIPTS_FOLDER = Rails.root.join("public", "machine_learning", "scripts").freeze
  DATA_FOLDER = Rails.root.join("public", "machine_learning", "data").freeze

  def initialize(job)
    @job = job
    @user = job.user
    @script = SCRIPTS_FOLDER.join(job.script)
    @kind = kind_for(job.script)
  end

  def run
    begin
      export_proposals_to_json
      export_budget_investments_to_json
      export_comments_to_json

      return unless run_machine_learning_scripts

      case kind
      when "tags"
        cleanup_tags!
        import_ml_tags
        import_ml_taggins
      when "related_content"
        cleanup_related_content!
        import_proposals_related_content
        import_budget_investments_related_content
      when "comments_summary"
        cleanup_summary_comments!
        import_ml_summary_comments
      end

      job.update!(finished_at: Time.current)
      MachineLearningInfo.find_or_create_by!(kind: kind).update!(generated_at: Time.current, script: script)
      Mailer.machine_learning_success(user).deliver_later
    rescue Exception => error
      handle_error(error)
      raise error
    end
  end
  handle_asynchronously :run, queue: "machine_learning"

  private

    def export_proposals_to_json
      Proposal::Exporter.new.to_json_file DATA_FOLDER.join("proposals.json")
    end

    def export_budget_investments_to_json
      Budget::Investment::Exporter.new(Array.new).to_json_file DATA_FOLDER.join("budget_investments.json")
    end

    def export_comments_to_json
      Comment::Exporter.new.to_json_file DATA_FOLDER.join("comments.json")
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

    def cleanup_related_content!
      RelatedContent.with_hidden.from_machine_learning.each(&:really_destroy!)
    end

    def cleanup_summary_comments!
      MlSummaryComment.destroy_all
    end

    def import_ml_summary_comments
      json_file = DATA_FOLDER.join("machine_learning_comments_textrank.json")
      json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
      json_data.each do |attributes|
        unless MlSummaryComment.find_by(commentable_id: attributes[:commentable_id],
                                        commentable_type: attributes[:commentable_type])
          MlSummaryComment.create!(attributes)
        end
      end
    end

    def import_proposals_related_content
      json_file = DATA_FOLDER.join("machine_learning_proposals_related_nmf.json")
      json_data = JSON.parse(File.read(json_file))
      json_data.each do |list|
        proposal_id = list.shift
        list.reject! { |value| value.to_s.empty? }
        list.each do |related_proposal_id|
          attributes = {
            parent_relationable_id: proposal_id,
            parent_relationable_type: "Proposal",
            child_relationable_id: related_proposal_id,
            child_relationable_type: "Proposal"
          }
          unless RelatedContent.find_by(attributes)
            RelatedContent.create!(attributes.merge(machine_learning: true, author: user))
          end
        end
      end
    end

    def import_budget_investments_related_content
      json_file = DATA_FOLDER.join("machine_learning_budget_investments_related_nmf.json")
      json_data = JSON.parse(File.read(json_file))
      json_data.each do |list|
        proposal_id = list.shift
        list.reject! { |value| value.to_s.empty? }
        list.each do |related_proposal_id|
          attributes = {
            parent_relationable_id: proposal_id,
            parent_relationable_type: "Budget::Investment",
            child_relationable_id: related_proposal_id,
            child_relationable_type: "Budget::Investment"
          }
          unless RelatedContent.find_by(attributes)
            RelatedContent.create!(attributes.merge(machine_learning: true, author: user))
          end
        end
      end
    end

    def import_ml_tags
      json_file = DATA_FOLDER.join("machine_learning_tags_nmf.json")
      json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
      json_data.each do |attributes|
        ml_tag_id = attributes.delete(:id)
        if attributes[:name].present?
          if attributes[:name].length >= 150
            attributes[:name] = attributes[:name].truncate(150)
          end
          unless Tag.find_by(name: attributes[:name])
            tag = Tag.create!(attributes)
            MlTag.create!(id: ml_tag_id, tag: tag)
          end
        end
      end
    end

    def import_ml_taggins
      json_file = DATA_FOLDER.join("machine_learning_taggings_nmf.json")
      json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
      json_data.each do |attributes|
        ml_tag_id = attributes[:tag_id]
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

    def handle_error(error)
      message = error.message
      backtrace = error.backtrace.select { |line| line.include?("machine_learning.rb") }
      full_error = ([message] + backtrace).join("<br>")
      job.update!(finished_at: Time.current, error: full_error)
      Mailer.machine_learning_error(user).deliver_later
    end

    def kind_for(filename)
      return "tags" if filename.start_with? "tags"
      return "related_content" if filename.start_with? "related_content"
      return "comments_summary" if filename.start_with? "comments"
    end
end
