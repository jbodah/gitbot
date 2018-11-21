module Gitbot
  class Config
    attr_accessor :github, :logger, :actions

    def initialize
      @actions = [
        Gitbot::MergePullRequest.new
      ]
    end
  end
end
