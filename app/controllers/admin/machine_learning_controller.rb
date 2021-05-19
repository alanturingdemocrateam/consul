class Admin::MachineLearningController < Admin::BaseController
  before_action :load_machine_learning_settings, only: :show
  before_action :load_machine_learning_job, only: :show
  before_action :reset_machine_learning_settings, only: :delete

  def show
  end

  def execute
    job = MachineLearningJob.first_or_initialize
    job.update!(script: params[:script],
                user: current_user,
                started_at: Time.current,
                finished_at: nil,
                error: nil)

    MachineLearning.new(job).run

    redirect_to admin_machine_learning_path
  end

  def cancel
    Delayed::Job.where(queue: "machine_learning").destroy_all
    MachineLearningJob.destroy_all

    redirect_to admin_machine_learning_path,
                notice: t("admin.machine_learning.notice.delete_generated_content")
  end

  private

    def load_machine_learning_job
      @machine_learning_job = MachineLearningJob.first_or_initialize
    end

    def reset_machine_learning_settings
      Setting["machine_learning.related_content"] = false
      Setting["machine_learning.summary_comments"] = false
      Setting["machine_learning.tags"] = false
    end

    def load_machine_learning_settings
      @machine_learning_settings = Setting.select { |setting| setting.key.start_with?("machine_learning.") }
    end
end
