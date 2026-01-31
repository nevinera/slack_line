module SlackLine
  class SentMessage
    extend Forwardable

    def initialize(original_content:, response:, client:)
      @original_content = original_content
      @response = response
      @client = client
    end

    attr_reader :original_content, :response
    def_delegators :response, :ts, :channel

    def inspect = "#<#{self.class} channel=#{channel.inspect} ts=#{ts.inspect}>"

    private

    attr_reader :client
  end
end
