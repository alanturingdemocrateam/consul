class Admin::MachineLearningController < Admin::BaseController
  before_action :load_machine_learning_job, only: :show

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

  def delete
    Delayed::Job.where(queue: "machine_learning").destroy_all
    reset_machine_learning_settings
    MachineLearning.cleanup!
    MachineLearningJob.destroy_all

    #TODO: Add translations
    redirect_to admin_machine_learning_path, notice: "Generated content has been successfully deleted."
  end

  private

    def load_machine_learning_job
      @machine_learning_job = MachineLearningJob.first_or_initialize
    end

    def reset_machine_learning_settings
      Setting["machine_learning.related_content"] = false,
      Setting["machine_learning.summary_comments"] = false,
      Setting["machine_learning.tags"] = false
    end
end
