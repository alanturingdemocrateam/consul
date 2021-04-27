class Comment::Exporter
  require "csv"

  def to_csv_file(filename)
    CSV.open(filename, "wb", headers: true) do |csv|
      csv << headers
      Comment.find_each { |comment| csv << csv_values(comment) }
    end
  end

  private

    def headers
      %w[id commentable_id commentable_type body]
    end

    def csv_values(comment)
      [
        comment.id,
        comment.commentable_id,
        comment.commentable_type,
        strip_tags(comment.body)
      ]
    end

    def strip_tags(html_string)
      ActionView::Base.full_sanitizer.sanitize(html_string)
    end
end
