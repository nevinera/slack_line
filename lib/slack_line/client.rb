module SlackLine
  class Client
    def initialize(base_config = nil, **overrides)
      @configuration = Configuration.new(base_config, **overrides)

      raise ArgumentError, "slack_token is required" if @configuration.slack_token.nil?
    end

    attr_reader :configuration

    def message(text_or_blocks = nil, &dsl_block) = Message.new(text_or_blocks, client: self, &dsl_block)

    def thread(*_args, **_kwargs) = nil

    def post_message(*_args, **_kwargs) = nil

    def post_thread(*_args, **_kwargs) = nil
  end
end
