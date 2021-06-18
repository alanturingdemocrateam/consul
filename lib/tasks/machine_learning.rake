namespace :machine_learning do
  desc "Imports proposals"
  task import_proposals: :environment do
    description_max_length = Proposal.description_max_length
    json_file = "/home/deploy/proposals.json"
    json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
    json_data.each do |attributes|
      Proposal.create!(title: attributes[:title].encode("utf-8"),
                       description: attributes[:description].encode("utf-8").truncate(description_max_length),
                       summary: attributes[:summary].encode("utf-8"),
                       terms_of_service: "1",
                       published_at: Time.current,
                       author_id: 1)
    end
  end

  desc "Imports comments"
  task import_comments: :environment do
    json_file = "/home/deploy/comments.json"
    json_data = JSON.parse(File.read(json_file)).each(&:deep_symbolize_keys!)
    json_data.each do |attributes|
      if attributes[:commentable_type] == "Proposal" && attributes[:body].present?
        attributes[:ancestry] = nil unless attributes[:ancestry].present?
        begin
          unless Comment.find_by(id: attributes[:id])
            Comment.create!(id: attributes[:id],
                            commentable_type: attributes[:commentable_type],
                            commentable_id: attributes[:commentable_id],
                            body: attributes[:body].encode("utf-8"),
                            user_id: 1)
          end
        rescue ActsAsTaggableOn::DuplicateTagError
        end
      end
    end
  end
end
