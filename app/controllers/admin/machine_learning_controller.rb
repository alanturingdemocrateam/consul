class Admin::MachineLearningController < Admin::BaseController
  before_action :load_scripts_info, only: :show
  before_action :load_machine_learning_job, only: :show
  before_action :reset_machine_learning_settings, only: :delete

  def show
    @script_kinds = MachineLearning.script_kinds
  end

  def execute
    job = MachineLearningJob.first_or_initialize
    job.update!(script: params[:script],
                user: current_user,
                started_at: Time.current,
                finished_at: nil,
                error: nil)

    MachineLearning.new(job).run

    redirect_to admin_machine_learning_path,
                notice: t("admin.machine_learning.script_info", email: current_user.email)
  end

  def cancel
    Delayed::Job.where(queue: "machine_learning").destroy_all
    MachineLearningJob.destroy_all

    redirect_to admin_machine_learning_path,
                notice: t("admin.machine_learning.notice.delete_generated_content")
  end

  private

    def load_scripts_info
      @scripts_info = []
      scripts_folder = MachineLearning::SCRIPTS_FOLDER
      Dir[scripts_folder.join("*.py")].each do |full_path_filename|
        @scripts_info << {
          name: full_path_filename.split("/").last,
          description: get_description_from(full_path_filename)
        }
      end
    end

    def get_description_from(filename)
      description = ""
      first_line = File.readlines(filename).first
      if first_line.start_with?("#")
        first_line.slice!(0)
        description << first_line.strip
      end

      if first_line.start_with?('"""')
        comment_found = false
        File.readlines(filename).each do |line|
          if line.start_with?('"""') && comment_found == false
            comment_found = true
            line.slice!('"""')
            description << line.strip.concat("<br>") if line.present?
          elsif line.include?('"""')
            line.slice!('"""')
            description << line.strip if line.present?
            break
          else
            description << line.strip.concat("<br>")
          end
        end
      end

      description.delete_suffix("<br>")
    end

    def load_machine_learning_job
      @machine_learning_job = MachineLearningJob.first_or_initialize
    end

    def reset_machine_learning_settings
      Setting["machine_learning.related_content"] = false
      Setting["machine_learning.comments_summary"] = false
      Setting["machine_learning.tags"] = false
    end
end
