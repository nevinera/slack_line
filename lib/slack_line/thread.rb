module SlackLine
  class Thread
    extend Forwardable
    include Enumerable
    include Memoization

    def initialize(*supplied_messages, client:, &dsl_block)
      @supplied_messages = supplied_messages
      @dsl_block = dsl_block
      @client = client

      validate!
    end

    # an Array of SlackLine::Messages
    memoize def messages = message_contents.map { |mc| convert_supplied_message(mc) }

    def_delegators :messages, :each, :[], :length, :size, :empty?

    memoize def builder_urls = messages.map(&:builder_url)

    private

    attr_reader :client

    def validate!
      validate_xor!
      validate_types!
    end

    def validate_xor!
      raise(ArgumentError, "Provide either texts/blocks/Messages or a DSL block, not both.") if @dsl_block && @supplied_messages.any?
      raise(ArgumentError, "Provide either texts/blocks/Messages or a DSL block.") unless @dsl_block || @supplied_messages.any?
    end

    def validate_types!
      @supplied_messages.each do |sm|
        unless sm.is_a?(String) || sm.is_a?(Slack::BlockKit::Blocks) || sm.is_a?(Message)
          raise(ArgumentError, "Invalid message type: #{sm.class}. Excepted a String, Slack::BlockKit::Blocks, or SlackLine::Message.")
        end
      end
    end

    memoize def dsl_contents = ThreadContext.new(&@dsl_block).contents

    # produces an Array of (mixed) Strings, Slack::BlockKit::Blocks, and SlackLine::Messages
    # (ThreadContext will produce Strings and Blocks)
    memoize def message_contents = @dsl_block ? dsl_contents : @supplied_messages

    def convert_supplied_message(sm)
      if sm.is_a?(String) || sm.is_a?(Slack::BlockKit::Blocks)
        Message.new(sm, client:)
      elsif sm.is_a?(Message)
        sm
      end
    end
  end
end
