module SlackLine
  Error = Class.new(StandardError)

  def self.configure
    yield(configuration)
  end

  # The Singleton configuration object - used by the Singleton client,
  # and as config defaults for other clients.
  def self.configuration
    @configuration ||= Configuration.new
  end

  class Configuration
    attr_accessor :slack_token, :look_up_users, :bot_name, :default_channel, :allow_dsl

    def initialize(base_config = nil)
      @slack_token = base_config&.slack_token || nil
      @look_up_users = base_config&.look_up_users || false
      @bot_name = base_config&.bot_name || nil
      @default_channel = base_config&.default_channel || nil
      @allow_dsl = @base_config.nil? || base_config.allow_dsl
    end
  end
end
