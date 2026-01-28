require "forwardable"

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

  def self.client
    @client ||= Client.new(configuration)
  end

  class << self
    extend Forwardable

    def_delegators(:client, :message, :thread, :send_message, :send_thread)
  end
end

require_relative "slack_line/configuration"
require_relative "slack_line/client"
