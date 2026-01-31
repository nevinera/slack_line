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

    memoize def target
      to ||
        configuration.default_channel ||
        raise(ConfigurationError, "No target channel specified and no default_channel configured.")
    end

    memoize def api_response
      slack_client.chat_postMessage(
        channel: target,
        blocks: content_data,
        thread_ts: thread_ts,
        username: configuration.bot_name
      )
    end

    attr_reader :message, :to, :thread_ts, :client
    def_delegators :client, :configuration, :slack_client
    def_delegators :message, :content

    memoize def content_data = content.as_json
  end
end
