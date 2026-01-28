module SlackLine
  class Configuration
    attr_accessor :slack_token, :look_up_users, :bot_name, :default_channel, :allow_dsl

    DEFAULTS = {
      slack_token: nil,
      look_up_users: false,
      bot_name: nil,
      default_channel: nil,
      allow_dsl: true
    }.freeze

    def initialize(base_config = nil, **overrides)
      @base_config = base_config
      @overrides = overrides

      @slack_token = cascade(:slack_token)
      @look_up_users = cascade(:look_up_users)
      @bot_name = cascade(:bot_name)
      @default_channel = cascade(:default_channel)
      @allow_dsl = cascade(:allow_dsl)
    end

    private

    def cascade(key)
      if @overrides&.key?(key)
        @overrides[key]
      elsif @base_config
        @base_config.public_send(key)
      else
        DEFAULTS[key]
      end
    end
  end
end
