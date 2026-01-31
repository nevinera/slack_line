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

    def inspect = "#<#{self.class} channel=#{channel.inspect} ts=#{ts.inspect}>"

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
