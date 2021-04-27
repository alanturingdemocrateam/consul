class MachineLearning
  attr_reader :user, :script
  attr_accessor :job

  SCRIPTS_FOLDER = Rails.root.join("lib", "machine_learning", "scripts").freeze

  def initialize(job)
    @job = job
    @user = job.user
    @script = full_path_for(job.script)
  end

  def run
    begin
      MachineLearning.cleanup!

      export_proposals_to_csv
      export_comments_to_csv

      return unless run_machine_learning_scripts

      import_ml_summary_comments
      import_proposals_related_content
      import_ml_tags
      import_ml_taggins

      job.update!(finished_at: Time.current)
      Mailer.machine_learning_success(user).deliver_later
    rescue Exception => error
      handle_error(error)
      raise error
    end
  end
  handle_asynchronously :run, queue: "machine_learning"

  def self.cleanup!
    MlSummaryComment.destroy_all
    RelatedContent.with_hidden.from_machine_learning.each(&:really_destroy!)
    MlTagging.destroy_all
    MlTag.destroy_all
  end

  private

    def export_proposals_to_csv
      Proposal::Exporter.new.to_csv_file full_path_for("proposals.csv")
    end

    def export_comments_to_csv
      Comment::Exporter.new.to_csv_file full_path_for("comments.csv")
    end

    def run_machine_learning_scripts
      output = `python #{script} 2>&1`
      result = $?.success?
      if result == false
        job.update!(finished_at: Time.current, error: output)
        exit -1
        Mailer.machine_learning_error(user).deliver_later
      end
      result
    end

    def import_ml_summary_comments
      csv_file = full_path_for("machine_learning_comments_textrank.csv")
      CSV.foreach(csv_file, col_sep: ";", headers: true) do |line|
        attributes = line.to_hash.deep_symbolize_keys!
        attributes.delete(:id)
        attributes[:commentable_type] = "Proposal"
        unless MlSummaryComment.find_by(commentable_id: attributes[:commentable_id],
                                        commentable_type: attributes[:commentable_type])
          MlSummaryComment.create!(attributes)
        end
      end
    end

    def import_proposals_related_content
      csv_file = full_path_for("machine_learning_proposals_related_nmf.csv")
      CSV.foreach(csv_file, col_sep: ";", headers: false) do |line|
        list = line.to_a
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

    def import_ml_tags
      csv_file = full_path_for("machine_learning_tags_nmf.csv")
      CSV.foreach(csv_file, col_sep: ";", headers: true) do |line|
        attributes = line.to_hash.deep_symbolize_keys!
        ml_tag_id = attributes.delete(:id)
        attributes.delete(:taggings_count)
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
      csv_file = full_path_for("machine_learning_taggings_nmf.csv")
      CSV.foreach(csv_file, col_sep: ";", headers: true) do |line|
        attributes = line.to_hash.deep_symbolize_keys!
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

    def full_path_for(filename)
      SCRIPTS_FOLDER.join(filename)
    end
end
