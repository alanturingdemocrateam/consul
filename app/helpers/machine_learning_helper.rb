module MachineLearningHelper
  def script_select_options
    scripts_folder = MachineLearning::SCRIPTS_FOLDER
    Dir[scripts_folder.join("*.py")].map do |full_path_filename|
      full_path_filename.split("/").last
    end
  end
end
