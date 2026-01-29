module SlackLine
  class ThreadContext
    def initialize(&block)
      @contents = []
      instance_exec(&block)
    end

    attr_reader :contents

    def text(text)
      fail(ArgumentError, "Text must be a String.") unless text.is_a?(String)

      @contents << text
    end

    # supplied should be a String, Slack::BlockKit::Blocks, or an already constructed SlackLine::Message
    def message(supplied = nil, &msg_block)
      if (supplied && msg_block) || (!supplied && !msg_block)
        fail(ArgumentError, "Provide either a supplied message or a message block, not both.")
      end
      validate_supplied_message!(supplied)

      @contents << (supplied || MessageContext.new(&msg_block).content)
    end

    private

    def validate_supplied_message!(sm)
      expected_types = [NilClass, String, Slack::BlockKit::Blocks, SlackLine::Message]
      unless expected_types.any? { |t| sm.is_a?(t) }
        fail(ArgumentError, "Invalid message type: #{sm.class}. Expected a String, Slack::BlockKit::Blocks, or SlackLine::Message.")
      end
    end
  end
end
