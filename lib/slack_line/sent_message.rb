module SlackLine
  class SentMessage
    extend Forwardable

    def initialize(original_content:, response:)
      @original_content = original_content
      @response = response
    end

    attr_reader :original_content, :response
    def_delegators :response, :ts, :channel

    def inspect = "#<#{self.class} channel=#{channel.inspect} ts=#{ts.inspect}>"
  end
end
