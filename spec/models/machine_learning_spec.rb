require "rails_helper"

describe MachineLearning do
  def full_sanitizer(string)
    ActionView::Base.full_sanitizer.sanitize(string)
  end

  let(:job) { create :machine_learning_job }

  describe ".cleanup!" do
    it "deletes all machine learning generated content" do
      create :ml_summary_comment, commentable: create(:proposal)
      create :related_content, :from_machine_learning
      tag = create(:tag)
      MlTag.create!(tag: tag)
      MlTagging.create!(tagging: create(:tagging, tag: tag))

      expect(MlSummaryComment.count).to be 1
      expect(RelatedContent.from_machine_learning.count).to be 2
      expect(Tag.count).to be 1
      expect(MlTag.count).to be 1
      expect(Tagging.count).to be 1
      expect(MlTagging.count).to be 1

      MachineLearning.cleanup!

      expect(MlSummaryComment.all).to be_empty
      expect(RelatedContent.from_machine_learning).to be_empty
      expect(Tag.all).to be_empty
      expect(MlTag.all).to be_empty
      expect(Tagging.all).to be_empty
      expect(MlTagging.all).to be_empty
    end
  end

  describe "#export_proposals_to_json" do
    it "creates a JSON file with all proposals" do
      first_proposal = create :proposal
      last_proposal = create :proposal

      machine_learning = MachineLearning.new(job)
      machine_learning.send(:export_proposals_to_json)

      json_file = machine_learning.send(:full_path_for, "proposals.json")
      json = JSON.parse(File.read(json_file))

      expect(json).to be_an Array
      expect(json.size).to be 2

      expect(json.first["id"]).to eq first_proposal.id
      expect(json.first["title"]).to eq first_proposal.title
      expect(json.first["summary"]).to eq full_sanitizer(first_proposal.summary)
      expect(json.first["description"]).to eq full_sanitizer(first_proposal.description)

      expect(json.last["id"]).to eq last_proposal.id
      expect(json.last["title"]).to eq last_proposal.title
      expect(json.last["summary"]).to eq full_sanitizer(last_proposal.summary)
      expect(json.last["description"]).to eq full_sanitizer(last_proposal.description)
    end
  end

  describe "#export_budget_investments_to_json" do
    it "creates a JSON file with all budget investments" do
      first_budget_investment = create :budget_investment
      last_budget_investment = create :budget_investment

      machine_learning = MachineLearning.new(job)
      machine_learning.send(:export_budget_investments_to_json)

      json_file = machine_learning.send(:full_path_for, "budget_investments.json")
      json = JSON.parse(File.read(json_file))

      expect(json).to be_an Array
      expect(json.size).to be 2

      expect(json.first["id"]).to eq first_budget_investment.id
      expect(json.first["title"]).to eq first_budget_investment.title
      expect(json.first["description"]).to eq full_sanitizer(first_budget_investment.description)

      expect(json.last["id"]).to eq last_budget_investment.id
      expect(json.last["title"]).to eq last_budget_investment.title
      expect(json.last["description"]).to eq full_sanitizer(last_budget_investment.description)
    end
  end

  describe "#export_comments_to_json" do
    it "creates a JSON file with all comments" do
      first_comment = create :comment
      last_comment = create :comment

      machine_learning = MachineLearning.new(job)
      machine_learning.send(:export_comments_to_json)

      json_file = machine_learning.send(:full_path_for, "comments.json")
      json = JSON.parse(File.read(json_file))

      expect(json).to be_an Array
      expect(json.size).to be 2

      expect(json.first["id"]).to eq first_comment.id
      expect(json.first["commentable_id"]).to eq first_comment.commentable_id
      expect(json.first["commentable_type"]).to eq first_comment.commentable_type
      expect(json.first["body"]).to eq full_sanitizer(first_comment.body)

      expect(json.last["id"]).to eq last_comment.id
      expect(json.last["commentable_id"]).to eq last_comment.commentable_id
      expect(json.last["commentable_type"]).to eq last_comment.commentable_type
      expect(json.last["body"]).to eq full_sanitizer(last_comment.body)
    end
  end

  describe "#run_machine_learning_scripts" do
    it "returns true if python script executed correclty" do
      machine_learning = MachineLearning.new(job)

      python_script = machine_learning.send(:full_path_for, "script.py")
      expect(machine_learning).to receive(:`).with("python #{python_script} 2>&1") do
        fork { exit 0 }
        Process.wait
      end

      expect(Mailer).not_to receive(:machine_learning_error)

      expect(machine_learning.send(:run_machine_learning_scripts)).to be true

      job.reload
      expect(job.finished_at).not_to be_present
      expect(job.error).not_to be_present
    end

    it "returns false if python script errored" do
      machine_learning = MachineLearning.new(job)

      python_script = machine_learning.send(:full_path_for, "script.py")
      expect(machine_learning).to receive(:`).with("python #{python_script} 2>&1") do
        fork { abort "error message" }
        Process.wait
      end

      mailer = double("mailer")
      expect(mailer).to receive(:deliver_later)
      expect(Mailer).to receive(:machine_learning_error).and_return mailer

      expect(machine_learning.send(:run_machine_learning_scripts)).to be false

      job.reload
      expect(job.finished_at).to be_present
      expect(job.error).not_to eq "error message"
    end
  end

  describe "#import_ml_summary_comments" do
    it "feeds the database using content from the JSON file generated by the machine learning script" do
      machine_learning = MachineLearning.new(job)

      proposal = create :proposal
      debate = create :debate
      investment = create :budget_investment

      data = [
        { commentable_id: proposal.id,
          commentable_type: "Proposal",
          body: "Summary comment for proposal with ID #{proposal.id}" },
        { commentable_id: debate.id,
          commentable_type: "Debate",
          body: "Summary comment for debate with ID #{debate.id}" },
        { commentable_id: investment.id,
          commentable_type: "Budget::Investment",
          body: "Summary comment for investment with ID #{investment.id}" }
      ]

      filename = "machine_learning_comments_textrank.json"
      json_file = machine_learning.send(:full_path_for, filename)
      expect(File).to receive(:read).with(json_file).and_return data.to_json

      machine_learning.send(:import_ml_summary_comments)

      expect(proposal.summary_comment.body).to eq "Summary comment for proposal with ID #{proposal.id}"
      expect(debate.summary_comment.body).to eq "Summary comment for debate with ID #{debate.id}"
      expect(investment.summary_comment.body).to eq "Summary comment for investment with ID #{investment.id}"
    end
  end

  describe "#import_proposals_related_content" do
    it "feeds the database using content from the JSON file generated by the machine learning script" do
      machine_learning = MachineLearning.new(job)

      proposal = create :proposal
      related_proposal = create :proposal
      other_related_proposal = create :proposal

      data = [
        [proposal.id, related_proposal.id, other_related_proposal.id]
      ]

      filename = "machine_learning_proposals_related_nmf.json"
      json_file = machine_learning.send(:full_path_for, filename)
      expect(File).to receive(:read).with(json_file).and_return data.to_json

      machine_learning.send(:import_proposals_related_content)

      expect(proposal.related_contents.count).to be 2
      expect(proposal.related_contents.first.child_relationable).to eq related_proposal
      expect(proposal.related_contents.last.child_relationable).to eq other_related_proposal
    end
  end

  describe "#import_budget_investments_related_content" do
    it "feeds the database using content from the JSON file generated by the machine learning script" do
      machine_learning = MachineLearning.new(job)

      investment = create :budget_investment
      related_investment = create :budget_investment
      other_related_investment = create :budget_investment

      data = [
        [investment.id, related_investment.id, other_related_investment.id]
      ]

      filename = "machine_learning_budget_investments_related_nmf.json"
      json_file = machine_learning.send(:full_path_for, filename)
      expect(File).to receive(:read).with(json_file).and_return data.to_json

      machine_learning.send(:import_budget_investments_related_content)

      expect(investment.related_contents.count).to be 2
      expect(investment.related_contents.first.child_relationable).to eq related_investment
      expect(investment.related_contents.last.child_relationable).to eq other_related_investment
    end
  end

  describe "#import_ml_tags" do
    it "feeds the database using content from the JSON file generated by the machine learning script" do
      machine_learning = MachineLearning.new(job)

      data = [
        { id: 12345,
          name: "Machine learning TAG 1" },
        { id: 54321,
          name: "Machine learning TAG 2" }
      ]

      filename = "machine_learning_tags_nmf.json"
      json_file = machine_learning.send(:full_path_for, filename)
      expect(File).to receive(:read).with(json_file).and_return data.to_json

      machine_learning.send(:import_ml_tags)

      expect(MlTag.count).to be 2
      expect(MlTag.find(12345).tag.name).to eq "Machine learning TAG 1"
      expect(MlTag.find(54321).tag.name).to eq "Machine learning TAG 2"
    end
  end

  describe "#import_ml_taggins" do
    it "feeds the database using content from the JSON file generated by the machine learning script" do
      machine_learning = MachineLearning.new(job)

      proposal_tag = create :tag
      ml_proposal_tag = create :ml_tag, tag: proposal_tag
      proposal = create :proposal

      debate_tag = create :tag
      ml_debate_tag = create :ml_tag, tag: debate_tag
      debate = create :debate

      investment_tag = create :tag
      ml_investment_tag = create :ml_tag, tag: investment_tag
      investment = create :budget_investment

      data = [
        { tag_id: ml_proposal_tag.id,
          taggable_id: proposal.id,
          taggable_type: "Proposal" },
        { tag_id: ml_debate_tag.id,
          taggable_id: debate.id,
          taggable_type: "Debate" },
        { tag_id: ml_investment_tag.id,
          taggable_id: investment.id,
          taggable_type: "Budget::Investment" }
      ]

      filename = "machine_learning_taggings_nmf.json"
      json_file = machine_learning.send(:full_path_for, filename)
      expect(File).to receive(:read).with(json_file).and_return data.to_json

      machine_learning.send(:import_ml_taggins)

      expect(proposal.tags.count).to be 1
      expect(proposal.tags.first).to eq proposal_tag
      expect(debate.tags.count).to be 1
      expect(debate.tags.first).to eq debate_tag
      expect(investment.tags.count).to be 1
      expect(investment.tags.first).to eq investment_tag
    end
  end
end
