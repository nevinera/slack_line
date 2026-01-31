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

    private

    attr_reader :client
  end
end
