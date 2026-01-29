module SlackLine
  class Message
    def initialize(text_or_blocks, client:, &dsl_block)
      @text_or_blocks = text_or_blocks
      @dsl_block = dsl_block
      @client = client

      validate!
    end

    def content
      @_content ||=
        if @dsl_block
          MessageContext.new(&@dsl_block).content
        elsif @text_or_blocks.is_a?(String)
          Slack::BlockKit.blocks { |b| b.section { |s| s.mrkdwn(text: @text_or_blocks) } }
        elsif @text_or_blocks.is_a?(Slack::BlockKit::Blocks)
          @text_or_blocks
        else
          raise ArgumentError, "Invalid content type: #{@text_or_blocks.class}"
        end
    end

    private

    def validate!
      validate_xor!
      validate_type!
    end

    def validate_xor!
      raise(ArgumentError, "Provide either text/blocks or a DSL block, not both.") if @dsl_block && @text_or_blocks
      raise(ArgumentError, "Provide either text/blocks or a DSL block.") unless @dsl_block || @text_or_blocks
    end

    def validate_type!
      unless @text_or_blocks.nil? || @text_or_blocks.is_a?(String) || @text_or_blocks.is_a?(Slack::BlockKit::Blocks)
        raise(ArgumentError, "Invalid content type: #{@text_or_blocks.class}")
      end
    end
  end
end
