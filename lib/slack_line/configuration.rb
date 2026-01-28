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

      @slack_token = cascade(:slack_token, "SLACK_LINE_SLACK_TOKEN", :string)
      @look_up_users = cascade(:look_up_users, "SLACK_LINE_LOOK_UP_USERS", :boolean)
      @bot_name = cascade(:bot_name, "SLACK_LINE_BOT_NAME", :string)
      @default_channel = cascade(:default_channel, "SLACK_LINE_DEFAULT_CHANNEL", :string)
      @allow_dsl = cascade(:allow_dsl, "SLACK_LINE_ALLOW_DSL", :boolean)
    end

    private

    def cascade(key, env_name, env_type)
      if @overrides&.key?(key)
        @overrides[key]
      elsif @base_config
        @base_config.public_send(key)
      elsif ENV.key?(env_name)
        from_env(env_name, env_type)
      else
        DEFAULTS[key]
      end
    end

    def from_env(env_name, env_type)
      value = ENV.fetch(env_name)

      if env_type == :boolean
        %w[1 true yes].include?(value.downcase)
      else
        value
      end
    end
  end
end
