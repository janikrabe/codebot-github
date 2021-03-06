# frozen_string_literal: true

# Portions (c) 2008 Logical Awesome, LLC (released under the MIT license).
# See the LICENSE file for the full MIT license text.

module Codebot
  module Formatters
    # This class formats pull_request_review_comment events.
    class PullRequestReviewComment < Formatter
      # Formats IRC messages for a pull_request_review_comment event.
      #
      # @return [Array<String>] the formatted messages
      def format
        ["#{summary}: #{format_url url}"]
      end

      def summary
        default_format % {
          repository: format_repository(repository_name),
          sender: format_user(sender_name),
          number: pull_number,
          hash: format_hash(commit_id),
          short: prettify(comment_body)
        }
      end

      def default_format
        '[%<repository>s] %<sender>s commented on pull request #%<number>s ' \
        '%<hash>s: %<summary>s'
      end

      def summary_url
        extract(:comment, :html_url).to_s
      end

      def comment_body
        extract(:comment, :body)
      end

      def commit_id
        extract(:comment, :commit_id)
      end

      def pull_number
        extract(:pull_request, :number)
      end
    end
  end
end
