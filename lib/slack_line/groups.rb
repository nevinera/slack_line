module SlackLine
  class Groups
    include Memoization
    include DiskCaching

    def initialize(client:)
      @client = client
    end

    memoize def all
      cached(config: client.configuration, key: "groups_all") { fetch_groups }
    end

    def find(handle:)
      groups_by_handle[handle.downcase]
    end

    private

    attr_reader :client

    def slack_client = client.slack_client

    memoize def fetch_groups
      slack_client.usergroups_list.usergroups || []
    end

    memoize def groups_by_handle = all.map { |g| [g.handle.downcase, g] }.to_h
  end
end
