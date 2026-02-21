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

    def append(*text_or_blocks, &dsl_block)
      extended = first.thread_from(*text_or_blocks, &dsl_block)
      SentThread.new(*sent_messages, *extended.sent_messages[1..])
    end

    def inspect = "#<#{self.class} channel=#{channel.inspect} size=#{size} thread_ts=#{thread_ts.inspect}>"

    def as_json
      {"type" => "thread", "messages" => sent_messages.map(&:as_json)}
    end

    def self.from_json(data, client:)
      raise ArgumentError, "Expected type 'thread', got #{data["type"].inspect}" unless data["type"] == "thread"

      new(*data["messages"].map { |m| SentMessage.from_json(m, client:) })
    end
  end
end
