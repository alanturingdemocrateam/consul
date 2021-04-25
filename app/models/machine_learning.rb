class MachineLearning
  attr_reader :user, :script
  attr_accessor :job

  def initialize(options)
    @user = options[:user]
    @script = options[:script]
    @job = options[:job]

    @script = full_path_for("script.py") ######## DELETE ########
    @job = MachineLearningJob.first_or_initialize ######## DELETE ########
  end

  def run
    begin
      # move this to the controller
      #script = full_path_for("script.py")
      #job = MachineLearningJob.first_or_initialize
      job.update!(script: script, user: user, started_at: Time.current, finished_at: nil, error: nil)

      export_proposals_to_csv
      export_comments_to_csv

      run_machine_learning_scripts

      delete_ml_summary_comments
      import_ml_summary_comments

      delete_proposals_related_content
      import_proposals_related_content

      delete_ml_taggins
      delete_ml_tags

      import_ml_tags
      import_ml_taggins

      job.update!(finished_at: Time.current)
    rescue Exception => e
      handle_rails_error(e)
    end
  end
  handle_asynchronously :run, queue: "machine_learning"

  def run_with_check
    rcb = RelatedContent.count
    mlrcb = RelatedContent.from_machine_learning.count
   
    tb = Tag.count
    tgb = Tagging.count
   
    run
   
    puts "related_content_before = #{rcb}"
    puts "ml_related_content_before = #{mlrcb}"
   
    puts "related_content_after = #{RelatedContent.count}"
    puts "ml_related_content_after = #{RelatedContent.from_machine_learning.count}"
   
    puts "tags_before = #{tb}"
    puts "ml_tags = #{MlTag.count}"
    puts "tags_after = #{Tag.count}"
   
    puts "taggings_before = #{tgb}"
    puts "ml_taggings = #{MlTagging.count}"
    puts "taggings_after = #{Tagging.count}"
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
        # notify user
        #exit -1 ######## UNCOMMENT LINE ########
      end
    end

    def delete_ml_summary_comments
      MlSummaryComment.destroy_all
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

    def delete_proposals_related_content
      RelatedContent.with_hidden.from_machine_learning.each(&:really_destroy!)
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

    def delete_ml_tags
      MlTag.destroy_all
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

    def delete_ml_taggins
      MlTagging.destroy_all
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

    def handle_rails_error(e)
      message = e.message
      backtrace = e.backtrace.select { |line| line.include?("machine_learning.rb") }
      error = ([message] + backtrace).join("\n")
      job.update!(finished_at: Time.current, error: error)
      # notify user
      #exit -1 ######## UNCOMMENT LINE ########
    end

    def full_path_for(filename)
      Rails.root.join("lib", "machine_learning", "scripts", filename)
    end
end
