# frozen_string_literal: false

# Portions (c) 2008 Logical Awesome, LLC (released under the MIT license).
# See the LICENSE file for the full MIT license text.

module Codebot
  module Formatters
    # This class formats push events.
    class Push < Formatter # rubocop:disable Metrics/ClassLength
      # Formats IRC messages for a push event.
      #
      # @return [Array<String>] the formatted messages
      def format
        ["#{summary}: #{format_url url}"] + distinct_commits.map do |commit|
          format_commit_message(commit)
        end
      end

      def url
        shorten_url summary_url
      end

      def summary # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/LineLength
        msg = "[#{format_repository repository_name}]"
        msg << " #{format_user(pusher_name)}"

        if created?
          if tag?
            msg << " tagged #{format_branch tag_name} at "
            msg << if base_ref
                     format_branch(base_ref_name)
                   else
                     format_hash(after_sha)
                   end
          else
            msg << " created #{format_branch branch_name}"
            msg << if base_ref
                     " from #{format_branch base_ref_name}"
                   else
                     " at #{format_hash after_sha}"
                   end

            len = distinct_commits.length
            msg << " (+#{format_number len, 'new commit', 'new commits'})"
          end
        elsif deleted?
          msg << " #{format_dangerous 'deleted'}"
          msg << " #{format_branch branch_name}"
          msg << " at #{format_hash before_sha}"
        elsif forced?
          msg << " #{format_dangerous 'force-pushed'}"
          msg << " #{format_branch branch_name}"
          msg << " from #{format_hash before_sha}"
          msg << " to #{format_hash after_sha}"
        elsif !commits.empty? && distinct_commits.empty?
          if base_ref
            msg << " merged #{format_branch base_ref_name}"
            msg << " into #{format_branch branch_name}"
          else
            msg << " fast-forwarded #{format_branch branch_name}"
            msg << " from #{format_hash before_sha}"
            msg << " to #{format_hash after_sha}"
          end
        else
          len = distinct_commits.length
          msg << " pushed #{format_number len, 'new commit', 'new commits'}"
          msg << " to #{format_branch branch_name}"
        end
        msg
      end

      def format_commit_message(commit) # rubocop:disable Metrics/AbcSize
        lines = commit['message'].to_s.lines
        title = lines.first.strip
        title << '...' unless lines.one?
        author = commit['author']['name'] if commit['author'].is_a? Hash
        sha = commit['id'].to_s
        "#{format_repository repository_name}/#{format_branch branch_name} " \
        "#{format_hash sha[0..6]} #{format_user author}: #{title}"
      end

      def summary_url # rubocop:disable Metrics/AbcSize
        if created?    then distinct_commits.empty? ? branch_url : compare_url
        elsif deleted? then before_sha_url
        elsif forced?  then branch_url
        elsif distinct_commits.length == 1
          distinct_commits.first['url']
        else
          compare_url
        end
      end

      def created?
        /\A0{40}\z/.match?(extract(:before))
      end

      def deleted?
        /\A0{40}\z/.match?(extract(:after))
      end

      def forced?
        extract(:forced)
      end

      def tag?
        %r{\Arefs/tags/}.match? ref
      end

      def commits
        extract(:commits)
      end

      def repository_name
        extract(:repository, :name)
      end

      def repository_url
        extract(:repository, :url)
      end

      def pusher_name
        extract(:pusher, :name) || 'somebody'
      end

      def ref
        extract(:ref).to_s
      end

      def ref_name
        ref.sub(%r{\Arefs/(heads|tags)/}, '')
      end

      alias tag_name ref_name
      alias branch_name ref_name

      def base_ref
        extract(:base_ref)
      end

      def base_ref_name
        base_ref.sub(%r{\Arefs/(heads|tags)/}, '')
      end

      def branch_url
        repository_url + '/commits/' + branch_name
      end

      def compare_url
        payload(:compare)
      end

      def before_sha
        extract(:before).to_s[0..6]
      end

      def before_sha_url
        repository_url + '/commits/' + before_sha
      end

      def after_sha
        extract(:after).to_s[0..6]
      end

      def after_sha_url
        repository_url + '/commits/' + after_sha
      end

      def distinct_commits
        extract(:distinct_commits) || commits.select do |commit|
          commit['distinct'] && !commit['message'].to_s.strip.empty?
        end
      end
    end
  end
end
