require "rails_helper"

describe "Machine learning" do
  let(:debate) { create(:debate) }
  let(:proposal) { create(:proposal) }
  let(:investment) { create(:budget_investment) }

  before do
    Setting["feature.machine_learning"] = true
    Setting["machine_learning.summary_comments"] = false
    Setting["machine_learning.related_content"] = false
    Setting["machine_learning.tags"] = false
  end

  scenario "Show Machine Learning summary comments correctly" do
    budget = create(:budget)
    investment = create(:budget_investment, budget: budget)
    ml_summary_comment_debate = create(:ml_summary_comment, commentable: debate)
    ml_summary_comment_proposal = create(:ml_summary_comment, commentable: proposal)
    ml_summary_comment_investment = create(:ml_summary_comment, commentable: investment)

    visit debate_path(debate)

    within "#comments" do
      expect(page).not_to have_content "Summary comments"
      expect(page).not_to have_content "Summary of comments elaborated by Machine Learning"
      expect(page).not_to have_content "#{ml_summary_comment_debate.body}"
    end

    visit proposal_path(proposal)

    within "#comments" do
      expect(page).not_to have_content "Summary comments"
      expect(page).not_to have_content "Summary of comments elaborated by Machine Learning"
      expect(page).not_to have_content "#{ml_summary_comment_proposal.body}"
    end

    visit budget_investment_path(budget, investment)

    within "#tab-comments" do
      expect(page).not_to have_content "Summary comments"
      expect(page).not_to have_content "Summary of comments elaborated by Machine Learning"
      expect(page).not_to have_content "#{ml_summary_comment_investment.body}"
    end

    Setting["machine_learning.summary_comments"] = true

    visit debate_path(debate)

    within "#comments" do
      expect(page).to have_content "Summary comments"
      expect(page).to have_content "Summary of comments elaborated by Machine Learning"
      expect(page).to have_content "#{ml_summary_comment_debate.body}"
    end

    visit proposal_path(proposal)

    within "#comments" do
      expect(page).to have_content "Summary comments"
      expect(page).to have_content "Summary of comments elaborated by Machine Learning"
      expect(page).to have_content "#{ml_summary_comment_proposal.body}"
    end

    visit budget_investment_path(budget, investment)

    within "#tab-comments" do
      expect(page).to have_content "Summary comments"
      expect(page).to have_content "Summary of comments elaborated by Machine Learning"
      expect(page).to have_content "#{ml_summary_comment_investment.body}"
    end
  end

  scenario "Show Machine Learning related content correctly" do
    proposal = create(:proposal)
    proposal2 = create(:proposal)
    debate = create(:debate)
    debate2 = create(:debate)
    budget = create(:budget)
    investment = create(:budget_investment, budget: budget)
    investment2 = create(:budget_investment, budget: budget)

    create(:related_content, parent_relationable: proposal, child_relationable: debate)
    create(:related_content, parent_relationable: investment, child_relationable: debate)
    create(:related_content, parent_relationable: proposal, child_relationable: debate2, machine_learning: true)
    create(:related_content, parent_relationable: proposal, child_relationable: proposal2, machine_learning: true)
    create(:related_content, parent_relationable: investment, child_relationable: proposal2, machine_learning: true)
    create(:related_content, parent_relationable: investment, child_relationable: investment2, machine_learning: true)
    create(:related_content, parent_relationable: debate, child_relationable: debate2, machine_learning: true)

    visit proposal_path(proposal)

    within ".related-content" do
      expect(page).to have_content "Related content (1)"
      expect(page).to have_selector(".related-content-title", count: 1)
      expect(page).to have_content "#{debate.title}"
    end

    visit debate_path(debate)

    within ".related-content" do
      expect(page).to have_content "Related content (2)"
      expect(page).to have_selector(".related-content-title", count: 2)
      expect(page).to have_content "#{proposal.title}"
      expect(page).to have_content "#{investment.title}"
    end

    visit budget_investment_path(budget, investment)

    within ".related-content" do
      expect(page).to have_content "Related content (1)"
      expect(page).to have_selector(".related-content-title", count: 1)
      expect(page).to have_content "#{debate.title}"
    end

    Setting["machine_learning.related_content"] = true

    visit proposal_path(proposal)

    within ".related-content" do
      expect(page).to have_content "Related content (3)"
      expect(page).to have_selector(".related-content-title", count: 3)
      expect(page).to have_content "#{debate.title}"
      expect(page).to have_content "#{debate2.title}"
      expect(page).to have_content "#{proposal2.title}"
    end

    visit debate_path(debate)

    within ".related-content" do
      expect(page).to have_content "Related content (3)"
      expect(page).to have_selector(".related-content-title", count: 3)
      expect(page).to have_content "#{proposal.title}"
      expect(page).to have_content "#{investment.title}"
      expect(page).to have_content "#{debate2.title}"
    end

    visit budget_investment_path(budget, investment)

    within ".related-content" do
      expect(page).to have_content "Related content (3)"
      expect(page).to have_selector(".related-content-title", count: 3)
      expect(page).to have_content "#{debate.title}"
      expect(page).to have_content "#{proposal2.title}"
      expect(page).to have_content "#{investment2.title}"
    end
  end

  scenario "Show Machine Learning tags correctly" do
    user_tag = Tag.create!(name: "user tag")
    ml_tag = Tag.create!(name: "machine learning tag")
    MlTag.create!(tag_id: ml_tag.id)

    proposal = create(:proposal, tag_list: [user_tag, ml_tag])

    visit proposal_path(proposal)

    within "#tags_proposal_#{proposal.id}" do
      expect(page).to have_link "user tag"
      expect(page).not_to have_link "machine learning tag"
    end

    Setting["machine_learning.tags"] = true

    visit proposal_path(proposal)

    within "#tags_proposal_#{proposal.id}" do
      expect(page).to have_link "user tag"
      expect(page).to have_link "machine learning tag"
    end
  end
end
