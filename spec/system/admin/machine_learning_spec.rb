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
    expect(page).to have_link "Settings"
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

    expect(page).to have_content "You will receive an email in #{admin.email} when the script finishes "\
                                 "running. You can then select which generated content you want to display."
    expect(page).to have_content "Select pyhton script to execute"

    allow_any_instance_of(MachineLearning).to receive(:run) do
      MachineLearningJob.first.update! finished_at: Time.current
    end

    select "tags_machine_learning.py", from: :script
    click_button "Execute script"

    expect(page).to have_content "Machine learning content has been generated successfully"

    expect(page).to have_content "Select pyhton script to execute"
    expect(page).to have_button "Execute script"
  end

  scenario "Settings" do
    visit admin_machine_learning_path

    within "#machine_learning_tabs" do
      click_link "Settings"
    end

    expect(page).to have_content "Related content"
    expect(page).to have_content "Adds automatically generated related content to proposals and "\
                                 "participatory budget projects"

    expect(page).to have_content "Comments summary"
    expect(page).to have_content "Displays an automatically generated comment summary on all items that "\
                                 "can be commented on."

    expect(page).to have_content "Tags"
    expect(page).to have_content "Generates automatic tags on all items that can be tagged on."

    expect(page).to have_button("No", count: 3)
  end

  scenario "Script started but not finished yet" do
    visit admin_machine_learning_path

    allow_any_instance_of(MachineLearning).to receive(:run)

    select "comments_machine_learning.py", from: :script
    click_button "Execute script"

    expect(page).to have_content "The script is running. The administrator who executed it will receive "\
                                 "an email when it is finished."

    job = MachineLearningJob.first
    expect(page).to have_content "Executed by: #{job.user.name}"
    expect(page).to have_content "Script name: #{job.script}"
    expect(page).to have_content "Started at: #{job.started_at}"

    expect(page).not_to have_content "Select pyhton script to execute"
    expect(page).not_to have_button "Execute script"
  end

  scenario "Admin can cancel operation if script is working for too long" do
    visit admin_machine_learning_path

    allow_any_instance_of(MachineLearning).to receive(:run) do
      MachineLearningJob.first.update! started_at: 25.hours.ago
    end

    select "related_content_machine_learning.py", from: :script
    click_button "Execute script"

    accept_confirm { click_link "Cancel operation" }

    expect(page).to have_content "Generated content has been successfully deleted."

    expect(page).to have_content "Select pyhton script to execute"
    expect(page).to have_button "Execute script"

    expect(Delayed::Job.where(queue: "machine_learning")).to be_empty

    expect(Setting["machine_learning.related_content"]).to be nil
    expect(Setting["machine_learning.summary_comments"]).to be nil
    expect(Setting["machine_learning.tags"]).to be nil
  end

  scenario "Script finished with an error" do
    visit admin_machine_learning_path

    allow_any_instance_of(MachineLearning).to receive(:run) do
      MachineLearningJob.first.update! finished_at: Time.current, error: "Error description"
    end

    select "tags_machine_learning.py", from: :script
    click_button "Execute script"

    expect(page).to have_content "An error has occurred. You can see the details below."

    job = MachineLearningJob.first
    expect(page).to have_content "Executed by: #{job.user.name}"
    expect(page).to have_content "Script name: #{job.script}"
    expect(page).to have_content "Error: Error description"

    expect(page).to have_content "You will receive an email in #{admin.email} when the script finishes "\
                                 "running. You can then select which generated content you want to display."

    expect(page).to have_content "Select pyhton script to execute"
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

    select "comments_machine_learning.py", from: :script
    click_button "Execute script"

    expect(page).to have_content "Machine learning content has been generated successfully"

    within "#machine_learning_tabs" do
      click_link "Settings"
    end

    expect(page).to have_button("No", count: 3)

    expect(Setting["machine_learning.related_content"]).to eq nil
    expect(Setting["machine_learning.summary_comments"]).to eq nil
    expect(Setting["machine_learning.tags"]).to eq nil
  end
end
