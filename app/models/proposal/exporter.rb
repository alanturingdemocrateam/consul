class Proposal::Exporter
  require "csv"

  def to_csv_file(filename = nil)
    filename ||= "proposals.csv"
    CSV.open(Rails.root.join(filename), "wb", headers: true) do |csv|
      csv << headers
      Proposal.find_each { |proposal| csv << csv_values(proposal) }
    end
  end

  private

    def headers
      %w[id title summary description]
    end

    def csv_values(proposal)
      [
        proposal.id,
        proposal.title,
        strip_tags(proposal.summary),
        strip_tags(proposal.description)
      ]
    end

    def strip_tags(html_string)
      ActionView::Base.full_sanitizer.sanitize(html_string)
    end
end
