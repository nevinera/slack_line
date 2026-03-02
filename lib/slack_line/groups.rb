module SlackLine
  class Groups
    include Memoization

    def initialize(slack_client:)
      @slack_client = slack_client
    end

    memoize def all = fetch_groups

    def find(handle:)
      groups_by_handle[handle.downcase]
    end

    private

    attr_reader :slack_client

    memoize def fetch_groups
      slack_client.usergroups_list.usergroups || []
    end

    memoize def groups_by_handle = all.map { |g| [g.handle.downcase, g] }.to_h
  end
end
