module SlackLine
  class Users
    include Memoization

    def initialize(slack_client:)
      @slack_client = slack_client
    end

    memoize def all = all_users.reject(&:deleted).reject(&:is_bot)

    def find(display_name:)
      users_by_display_name[display_name.downcase] ||
        fail(UserNotFoundError, "User with display name '#{display_name}' was not found.")
    end

    private

    attr_reader :slack_client

    def fetch_page(cursor: nil)
      params = {limit: 200}
      params[:cursor] = cursor if cursor

      response = slack_client.users_list(params)
      users = response.members || []
      next_cursor = response.dig("response_metadata", "next_cursor")

      [users, next_cursor]
    end

    memoize def all_users
      all_users, cursor = fetch_page

      while cursor
        users, cursor = fetch_page(cursor:)
        all_users.concat(users)
        break if cursor.nil? || cursor.empty?
      end

      all_users
    end

    memoize def users_by_display_name = all.map { |u| [u.profile.display_name.downcase, u] }.to_h
  end
end
