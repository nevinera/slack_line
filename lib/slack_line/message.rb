module SlackLine
  class Message
    extend Forwardable
    include Memoization

    def initialize(*text_or_blocks, client:, &dsl_block)
      @text_or_blocks = text_or_blocks
      @dsl_block = dsl_block
      @client = client

      validate!
    end

    memoize def content
      if @dsl_block
        MessageContext.new(&@dsl_block).content
      elsif strings?(@text_or_blocks)
        convert_multistring(*@text_or_blocks)
      elsif blocks?(@text_or_blocks)
        @text_or_blocks.first
      end
    end

    # easier prototyping/verification. You can definitely construct illegal messages
    # using the library in various ways, but if Slack's BlockKit Builder accepts it,
    # it's probably right.
    memoize def builder_url
      blocks_json = {blocks: content_data}.to_json
      escaped_json = CGI.escape(blocks_json)
      "https://app.slack.com/block-kit-builder##{escaped_json}"
    end

    def post(to: nil, thread_ts: nil)
      target = to || configuration.default_channel || raise(ConfigurationError, "No target channel specified and no default_channel configured.")
      response = slack_client.chat_postMessage(channel: target, blocks: content_data, thread_ts:, username: configuration.bot_name)
      SentMessage.new(content: content_data, response:, client:)
    end

    private

    attr_reader :client
    def_delegators :client, :slack_client, :configuration

    def validate!
      validate_xor!
      validate_type!
    end

    def validate_xor!
      raise(ArgumentError, "Provide either strings/Slack::BlockKit::Blocks, or a DSL block, not both.") if @dsl_block && @text_or_blocks.any?
      raise(ArgumentError, "Provide either strings/Slack::BlockKit::Blocks, or a DSL block.") unless @dsl_block || @text_or_blocks.any?
    end

    def validate_type!
      unless @text_or_blocks.empty? || blocks?(@text_or_blocks) || strings?(@text_or_blocks)
        raise(ArgumentError, "Invalid content type: #{@text_or_blocks.class}")
      end
    end

    def blocks?(obj) = obj.is_a?(Array) && obj.size == 1 && obj.first.is_a?(Slack::BlockKit::Blocks)

    def strings?(obj) = obj.is_a?(Array) && obj.size > 0 && obj.all? { |item| item.is_a?(String) }

    def convert_multistring(*strs)
      Slack::BlockKit.blocks do |b|
        strs.each do |str|
          b.section { |s| s.mrkdwn(text: str) }
        end
      end
    end

    memoize def content_data = content.as_json
  end
end
