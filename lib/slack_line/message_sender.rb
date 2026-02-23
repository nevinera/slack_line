module SlackLine
  class MessageSender
    extend Forwardable
    include Memoization

    def initialize(message:, client:, to: nil, thread_ts: nil)
      @message = message
      @client = client
      @to = to
      @thread_ts = thread_ts
    end

    def post = SentMessage.new(content: content_data, response: api_response, client:)

    private

    memoize def supplied_target
      to ||
        configuration.default_channel ||
        raise(ConfigurationError, "No target channel specified and no default_channel configured.")
    end

    memoize def target
      if supplied_target.start_with?("@")
        name = supplied_target[1..]
        client.users.find(display_name: name).id
      else
        supplied_target
      end
    end

    MAX_RETRIES = 2

    memoize def api_response
      if configuration.backoff
        with_rate_limit_backoff { call_api }
      else
        call_api
      end
    end

    def call_api
      slack_client.chat_postMessage(
        channel: target,
        blocks: content_data,
        thread_ts: thread_ts,
        username: configuration.bot_name
      )
    end

    def with_rate_limit_backoff
      retries = 0
      begin
        yield
      rescue Slack::Web::Api::Errors::TooManyRequestsError => e
        raise if retries >= MAX_RETRIES
        retries += 1
        sleep(e.retry_after)
        retry
      end
    end

    attr_reader :message, :to, :thread_ts, :client
    def_delegators :client, :configuration, :slack_client
    def_delegators :message, :content

    memoize def content_data = content.as_json
  end
end
