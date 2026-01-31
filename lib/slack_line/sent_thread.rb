module SlackLine
  class SentThread
    extend Forwardable
    include Enumerable

    def initialize(*sent_messages)
      @sent_messages = sent_messages.freeze
    end

    attr_reader :sent_messages
    alias_method :messages, :sent_messages
    def_delegators :sent_messages, :each, :map, :size, :first, :last, :empty?
    def_delegators :first, :channel, :ts
    alias_method :thread_ts, :ts

    def inspect = "#<#{self.class} channel=#{channel.inspect} size=#{size} thread_ts=#{thread_ts.inspect}>"
  end
end
