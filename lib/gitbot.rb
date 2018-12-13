require "gitbot/version"
require "gitbot/config"
require "gitbot/merge_pull_request"

module Gitbot
  class << self
    SLEEP = 30

    def configure!(progname:)
      require 'yaml'
      require 'github_api'

      repo_owner = ENV['REPO_OWNER'] || "cargurus-sem"
      repo = ENV['REPO'] || "cg-ruby-sem"

      Gitbot.configure do |bot|
        env = YAML.load_file(File.expand_path("~/.env.yml"))
        bot.github = Github.new do |c|
          c.endpoint = env["github_api_base_url"]
          c.site = env["github_base_url"]
          c.oauth_token = env["github_access_token"]
          c.user = repo_owner
          c.repo = repo
        end

        bot.logger = Logger.new($stdout)
        bot.logger.progname = progname
      end
    end

    def start!
      loop do
        config.logger.info { "Woke up..." }
        prs = config.github.pull_requests.list

        prs.each do |pr|
          config.actions.each do |action|
            action.apply(config, pr)
          end
        end

        config.logger.info { "Sleeping..." }
        sleep SLEEP
      end
    end

    def configure
      yield config
    end

    def config
      @config ||= Gitbot::Config.new
    end
  end
end
