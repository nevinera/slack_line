require "forwardable"
require "slack-ruby-block-kit"
require "json"
require "cgi"

require_relative "slack_line/memoization"

module SlackLine
  Error = Class.new(StandardError)

  class << self
    extend Forwardable
    include Memoization

    # The Singleton configuration object - used by the Singleton client,
    # and as config defaults for other clients.
    memoize def configuration = Configuration.new

    def configure = yield(configuration)

    memoize def client = Client.new(configuration)

    def_delegators(:client, :message, :thread, :post_message, :post_thread)
  end
end

glob = File.expand_path("../slack_line/*.rb", __FILE__)
Dir.glob(glob).sort.each { |f| require(f) }
