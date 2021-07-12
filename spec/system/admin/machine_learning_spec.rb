require "rails_helper"

describe "Machine learning" do
  let(:admin) { create(:administrator) }

  before do
    login_as(admin.user)
    Setting["feature.machine_learning"] = true
  end

  scenario "Section only appears if feature is enabled" do
    Setting["feature.machine_learning"] = false

    visit admin_root_path

    within "#admin_menu" do
      expect(page).not_to have_link "AI / Machine learning"
    end

    Setting["feature.machine_learning"] = true

    visit admin_root_path

    within "#admin_menu" do
      expect(page).to have_link "AI / Machine learning"
    end

    click_link "AI / Machine learning"

    expect(page).to have_content "AI / Machine learning"
    expect(page).to have_content "This functionality is experimental"
    expect(page).to have_link "Execute script"
    expect(page).to have_link "Settings / Generated content"
    expect(page).to have_link "Help"
    expect(page).to have_current_path(admin_machine_learning_path)
  end

  scenario "Show message if feature is disabled" do
    Setting["feature.machine_learning"] = false

    visit admin_machine_learning_path

    expect(page).to have_content "This feature is disabled. To use Machine Learning you can enable it from "\
                                 "the settings page"
    expect(page).to have_link("settings page", href: admin_settings_path(anchor: "tab-feature-flags"))
  end

  scenario "Script executed sucessfully" do
    visit admin_machine_learning_path

    expect(page).to have_content "Select python script to execute"

    allow_any_instance_of(MachineLearning).to receive(:run) do
      MachineLearningJob.first.update! finished_at: Time.current
    end

    select "proposals_related_content_and_tags_nmf.py", from: :script
    click_button "Execute script"

    expect(page).to have_content "The last script has been executed successfully."
    expect(page).to have_content "You will receive an email in #{admin.email} when the script "\
                                 "finishes running."

    expect(page).to have_content "Select python script to execute"
    expect(page).to have_button "Execute script"
  end

  scenario "Settings" do
    visit admin_machine_learning_path

    within "#machine_learning_tabs" do
      click_link "Settings / Generated content"
    end

    expect(page).to have_content "Related content"
    expect(page).to have_content "Adds automatically generated related content to proposals and "\
                                 "participatory budget projects"

    expect(page).to have_content "Comments summary"
    expect(page).to have_content "Displays an automatically generated comment summary on all items that "\
                                 "can be commented on."

    expect(page).to have_content "Tags"
    expect(page).to have_content "Generates automatic tags on all items that can be tagged on."

    expect(page).to have_content("No content generated yet", count: 3)
    expect(page).not_to have_button "Yes"
    expect(page).not_to have_button "No"
  end

  scenario "Script started but not finished yet" do
    visit admin_machine_learning_path

    allow_any_instance_of(MachineLearning).to receive(:run)

    select "proposals_related_content_and_tags_nmf.py", from: :script
    click_button "Execute script"

    expect(page).to have_content "The script is running. The administrator who executed it will receive "\
                                 "an email when it is finished."

    job = MachineLearningJob.first
    expect(page).to have_content "Executed by: #{job.user.name}"
    expect(page).to have_content "Script name: #{job.script}"
    expect(page).to have_content "Started at: #{job.started_at}"

    expect(page).not_to have_content "Select python script to execute"
    expect(page).not_to have_button "Execute script"
  end

  scenario "Admin can cancel operation if script is working for too long" do
    visit admin_machine_learning_path

    allow_any_instance_of(MachineLearning).to receive(:run) do
      MachineLearningJob.first.update! started_at: 25.hours.ago
    end

    select "proposals_related_content_and_tags_nmf.py", from: :script
    click_button "Execute script"

    accept_confirm { click_link "Cancel operation" }

    expect(page).to have_content "Generated content has been successfully deleted."

    expect(page).to have_content "Select python script to execute"
    expect(page).to have_button "Execute script"

    expect(Delayed::Job.where(queue: "machine_learning")).to be_empty

    expect(Setting["machine_learning.related_content"]).to be nil
    expect(Setting["machine_learning.comments_summary"]).to be nil
    expect(Setting["machine_learning.tags"]).to be nil
  end

  scenario "Script finished with an error" do
    visit admin_machine_learning_path

    allow_any_instance_of(MachineLearning).to receive(:run) do
      MachineLearningJob.first.update! finished_at: Time.current, error: "Error description"
    end

    select "proposals_related_content_and_tags_nmf.py", from: :script
    click_button "Execute script"

    expect(page).to have_content "An error has occurred. You can see the details below."

    job = MachineLearningJob.first
    expect(page).to have_content "Executed by: #{job.user.name}"
    expect(page).to have_content "Script name: #{job.script}"
    expect(page).to have_content "Error: Error description"

    expect(page).to have_content "You will receive an email in #{admin.email} when the script "\
                                 "finishes running."

    expect(page).to have_content "Select python script to execute"
    expect(page).to have_button "Execute script"
  end

  scenario "Email content received by the user who execute the script" do
    reset_mailer
    Mailer.machine_learning_success(admin.user).deliver

    email = open_last_email
    expect(email).to have_subject "Machine Learning - Content has been generated successfully"
    expect(email).to have_content "Machine Learning script"
    expect(email).to have_content "Content has been generated successfully."
    expect(email).to have_link "Visit Machine Learning panel"
    expect(email).to deliver_to(admin.user.email)

    reset_mailer
    Mailer.machine_learning_error(admin.user).deliver

    email = open_last_email
    expect(email).to have_subject "Machine Learning - An error has occurred running the script"
    expect(email).to have_content "Machine Learning script"
    expect(email).to have_content "An error has occurred running the Machine Learning script."
    expect(email).to have_link "Visit Machine Learning panel"
    expect(email).to deliver_to(admin.user.email)
  end

  scenario "Machine Learning visualization settings are disabled by default" do
    visit admin_machine_learning_path

    allow_any_instance_of(MachineLearning).to receive(:run) do
      MachineLearningJob.first.update! finished_at: Time.current
    end

    select "budgets_summary_comments_textrank.py", from: :script
    click_button "Execute script"

    expect(page).to have_content "The last script has been executed successfully."

    within "#machine_learning_tabs" do
      click_link "Settings / Generated content"
    end

    expect(page).to have_content("No content generated yet", count: 3)
    expect(page).not_to have_button "Yes"
    expect(page).not_to have_button "No"

    expect(Setting["machine_learning.related_content"]).to eq nil
    expect(Setting["machine_learning.comments_summary"]).to eq nil
    expect(Setting["machine_learning.tags"]).to eq nil
  end

  scenario "Show script descriptions" do
    visit admin_machine_learning_path

    select "proposals_summary_comments_textrank.py", from: :script

    within "#script_descriptions" do
      expect(page).to have_content "This script generates for each proposal a summary of all its comments."
      expect(page).to have_content "Running time: Max 1 hour for 10.000 proposals."
      expect(page).to have_content "Technique used: GloVe embeddings and TextRank."
    end

    select "proposals_related_content_and_tags_nmf.py", from: :script

    within "#script_descriptions" do
      expect(page).to have_content "Related Proposals and Tags"
      expect(page).to have_content "This script generates for each proposal: a) Tags, b) List of related proposals."
      expect(page).to have_content "Running time: Max 2 hours for 10.000 proposals."
      expect(page).to have_content "Technique used: NNMF and Euclidean distance between proposals."
    end
  end

  scenario "Show output files info on settins page" do
    require "fileutils"
    FileUtils.mkdir_p Rails.root.join("public", "machine_learning", "data")

    visit admin_machine_learning_path

    within "#machine_learning_tabs" do
      click_link "Settings / Generated content"
    end

    expect(page).to have_content("No content generated yet.", count: 3)

    visit admin_machine_learning_path

    allow_any_instance_of(MachineLearning).to receive(:run) do
      MachineLearningJob.first.update! finished_at: Time.current
      create :machine_learning_info, script: "proposals_summary_comments_textrank.py", kind: "comments_summary"
      comments_file = MachineLearning::DATA_FOLDER.join(MachineLearning.comments_filename)
      File.open(comments_file, "w") { |file| file.write([].to_json) }
      proposals_comments_summary_file = MachineLearning::DATA_FOLDER.join(MachineLearning.proposals_comments_summary_filename)
      File.open(proposals_comments_summary_file, "w") { |file| file.write([].to_json) }
    end

    select "budgets_related_content_and_tags_nmf.py", from: :script
    click_button "Execute script"

    expect(page).to have_content "The last script has been executed successfully."

    visit admin_machine_learning_path

    within "#machine_learning_tabs" do
      click_link "Settings / Generated content"
    end

    info = MachineLearningInfo.first

    expect(page).to have_content "Last execution\n#{info.generated_at.strftime("%Y/%m/%d - %H:%M")} | "\
                                 "#{info.updated_at.strftime("%Y/%m/%d - %H:%M")}"
    expect(page).to have_content "Excuted script:"
    expect(page).to have_content "#{info.script}"
    expect(page).to have_content "Output files:"
    expect(page).to have_link "ml_comments_summaries_proposals.json",
                              href: MachineLearning.data_path("ml_comments_summaries_proposals.json")
  end
end
