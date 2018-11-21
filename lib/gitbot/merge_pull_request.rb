module Gitbot
  class MergePullRequest
    def apply(config, pr)
      if asked_to_merge?(config, pr) && !acked_pr?(config, pr)
        merge_when_ready(config, pr)
        ack_pr(config, pr)
      end
    end

    def run(config, pr)
      with_file_lock do
        config.logger.info { "Watching PR #{pr.number}" }
        merged = false
        until merged
          if pr.merged
            merged = true
            config.logger.info { "Successfully merged PR #{pr.number} - #{pr.title}" }
            break
          elsif pr.mergeable_state == "behind"
            config.logger.info { "Behind Master; merging Master in branch" }
            config.github.repos.merging.merge base: pr.head.ref, head: "master"
          elsif pr.mergeable
            config.logger.info { "Merging PR #{pr.number} - #{pr.title}" }
            begin
              config.github.pull_requests.merge(config.github.user, config.github.repo, pr.number)
            rescue => e
              config.logger.info { "Merge failed: #{e}" }
            end
          else
            config.logger.info { "PR not mergeable #{pr.number} - #{pr.title}; #{pr.mergeable_state}" }
          end
          config.logger.info { "Backing off" }
          sleep 20
          pr = config.github.pull_requests.get(config.github.user, config.github.repo, pr.number)
        end
      end
    end

    private

    def with_file_lock
      lock_file = File.expand_path('../../../merge_pull_request.lock', __FILE__)
      File.open(lock_file, 'w') do |f|
        f.flock(File::LOCK_EX)
        yield
      end
    end

    def asked_to_merge?(config, pr)
      config.github.issues.comments.list(number: pr.number).any? { |comment| comment.body == "@bot merge" }
    end

    def merge_when_ready(config, pr)
      config.logger.info { "Forking merge worker - #{pr.number}" }
      fork { run(config, pr) }
    end

    def acked_pr?(config, pr)
      config.github.issues.comments.list(number: pr.number).any? { |comment| comment.body == ":robot: beepboop merging" }
    end

    def ack_pr(config, pr)
      config.logger.info { "Acking PR - #{pr.number}" }
      config.github.issues.comments.create(number: pr.number, body: ":robot: beepboop merging")
    end
  end
end
