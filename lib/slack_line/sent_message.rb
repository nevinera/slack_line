module SlackLine
  class SentMessage
    extend Forwardable

    def initialize(response:, client:, content:, priorly: nil)
      @content = content
      @priorly = priorly
      @response = response
      @client = client
    end

    attr_reader :content, :priorly, :response
    def_delegators :response, :ts, :channel

    def thread_ts = response.thread_ts || ts

    def inspect = "#<#{self.class} channel=#{channel.inspect} ts=#{ts.inspect}>"

    def as_json
      {"type" => "message", "ts" => ts, "channel" => channel,
       "thread_ts" => response.thread_ts, "content" => content, "priorly" => priorly}
    end

    def self.from_json(data, client:)
      raise ArgumentError, "Expected type 'message', got #{data["type"].inspect}" unless data["type"] == "message"

      response_hash = {ts: data["ts"], channel: data["channel"]}
      response_hash[:thread_ts] = data["thread_ts"] if data["thread_ts"]
      response = Slack::Messages::Message.new(response_hash)
      new(response:, client:, content: data["content"], priorly: data["priorly"])
    end

    def append(*text_or_blocks, &dsl_block)
      appended = Thread.new(*text_or_blocks, client:, &dsl_block)
      new_sent = appended.messages.map { |m| m.post(to: channel, thread_ts:) }
      SentThread.new(self, *new_sent)
    end

    def update(*text_or_blocks, &dsl_block)
      updated_message = Message.new(*text_or_blocks, client:, &dsl_block)
      new_content = updated_message.content.as_json
      response = slack_client.chat_update(channel:, ts:, blocks: new_content)
      SentMessage.new(content: new_content, priorly: content, response:, client:)
    end

    private

    attr_reader :client
    def_delegators :client, :slack_client
  end
end
