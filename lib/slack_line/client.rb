module SlackLine
  class Client
    def initialize(base_config = nil, **overrides)
      @configuration = Configuration.new(base_config, **overrides)

      raise ArgumentError, "slack_token is required" if @configuration.slack_token.nil?
    end

    attr_reader :configuration

    def message(*text_or_blocks, &dsl_block) = Message.new(*text_or_blocks, client: self, &dsl_block)

    def thread(*messages, &dsl_block) = Thread.new(*messages, client: self, &dsl_block)

  end
end
