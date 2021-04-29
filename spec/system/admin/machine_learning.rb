require "rails_helper"

describe "Machine learning" do
  let!(:admin) { create(:administrator, user: create(:user)) }

  before { login_as(admin.user) }

  scenario "Section only appears if feature is enabled" do
    Setting["feature.machine_learning"] = false

    visit admin_root_path

    within "#admin_menu" do
     expect(page).not_to have_link "Machine learning"
    end

    Setting["feature.machine_learning"] = true

    visit admin_root_path

    within "#admin_menu" do
     expect(page).to have_link "Machine learning"
    end

    click_link "Machine learning"

    expect(page).to have_content "Machine learning"
    expect(page).to have_content "This functionality is experimental"
    expect(page).to have_link "Machine learning scripts"
    expect(page).to have_link "Help about machine learning"
    expect(page).to have_current_path(admin_machine_learning_path)
  end

  scenario "Admin can execute a script" do
    Setting["feature.machine_learning"] = false

    visit admin_machine_learning_path

    expect(page).to have_content "You will receive an email in #{admin.email} when the script finishes running. "\
                                 "You can then select which generated content you want to display."
    expect(page).to have_content "Select pyhton script to execute"

    select "script.py", from: :script
    expect(page).to have_button "Execute script"

    # TODO
    # visit admin_machine_learning_path
    # expect(page).to have_content "Machine learning content has been generated successfully"
  end

  scenario "Sucessfull script message" do
    create(:machine_learning_job)

    visit admin_machine_learning_path

    expect(page).to have_content "Machine learning content has been generated successfully"

    expect(page).to have_content "Related content"
    expect(page).to have_content "Adds automatically generated related content to proposals and "\
                                 "participatory budget projects"

    expect(page).to have_content "Comments summary"
    expect(page).to have_content "Displays an automatically generated comment summary on all items that "\
                                 "can be commented on."

    expect(page).to have_content "Tags"
    expect(page).to have_content "Generates automatic tags for proposals replacing those added by users."

    expect(page).to have_button("No", count: 3)
    expect(page).to have_link "Delete generated content"

    expect(page).not_to have_content "Select pyhton script to execute"
    expect(page).not_to have_button "Execute script"
  end

  scenario "Working script message" do
    job = create(:machine_learning_job, :working)

    visit admin_machine_learning_path

    expect(page).to have_content "The script is running. The administrator who executed it will receive an email "\
                                 "when it is finished."

    expect(page).to have_content "Executed by: #{job.user.name}"
    expect(page).to have_content "Script name: #{job.script}"
    expect(page).to have_content "Started at: #{job.started_at}"

    expect(page).not_to have_content "Select pyhton script to execute"
    expect(page).not_to have_button "Execute script"
  end

  scenario "Error script message and form to execute again" do
    job = create(:machine_learning_job, :with_error)

    visit admin_machine_learning_path

    expect(page).to have_content "An error has occurred. You can see the details below."

    expect(page).to have_content "Executed by: #{job.user.name}"
    expect(page).to have_content "Script name: #{job.script}"
    expect(page).to have_content "Error: Error description"

    expect(page).to have_content "You will receive an email in #{admin.email} when the script finishes running. "\
                                 "You can then select which generated content you want to display."

    expect(page).to have_content "Select pyhton script to execute"
    expect(page).to have_button "Execute script"
  end

  scenario "Send email to user who execute the script when finish" do
    user = create(:user)
    create(:administrator, user: user)
    create(:machine_learning_job, user: user)

    reset_mailer
    Mailer.machine_learning_success(user).deliver

    email = open_last_email
    expect(email).to have_subject "Machine Learning - Content has been generated successfully"
    expect(email).to have_content "Machine Learning script"
    expect(email).to have_content "Content has been generated successfully."
    expect(email).to have_link "Visit Machine Learning panel"
    expect(email).to deliver_to(user.email)

    create(:machine_learning_job, :with_error, user: user)

    reset_mailer
    Mailer.machine_learning_error(user).deliver

    email = open_last_email
    expect(email).to have_subject "Machine Learning - An error has occurred running the script"
    expect(email).to have_content "Machine Learning script"
    expect(email).to have_content "An error has occurred running the Machine Learning script."
    expect(email).to have_link "Visit Machine Learning panel"
    expect(email).to deliver_to(user.email)
  end

  scenario "Machine Learning settings are disabled by default" do
    create(:machine_learning_job)

    visit admin_machine_learning_path

    expect(page).to have_button("No", count: 3)

    expect(Setting["machine_learning.related_content"]).to eq nil
    expect(Setting["machine_learning.summary_comments"]).to eq nil
    expect(Setting["machine_learning.tags"]).to eq nil
  end

  scenario "Admin can delete Machine Learning generated content" do
    create(:machine_learning_job)

    visit admin_machine_learning_path

    accept_confirm { click_link "Delete generated content" }

    expect(page).to have_content "Generated content has been successfully deleted."

    expect(page).to have_content "Select pyhton script to execute"
    expect(page).to have_button "Execute script"
  end
end
