module SlackLine
  # Runs a DSL block against a builder. A block that takes no arguments runs
  # with the builder as self; a block that takes an argument receives the
  # builder instead, so the caller keeps its own methods and instance variables.
  #
  # When a block with no arguments calls a method the builder lacks but the
  # caller has, we raise an error that explains the block-argument form.
  # We can't catch instance variables the same way: inside a bare block,
  # @foo reads the builder's ivar, which is nil, and Ruby raises nothing.
  module DslBlock
    protected

    attr_reader :dsl_caller

    private

    def run_dsl_block(block)
      return block.call(self) unless block.arity.zero?

      @dsl_caller = find_dsl_caller(block)
      instance_exec(&block)
    end

    # A nested bare block's receiver is the outer builder, so ask it for the
    # original caller instead.
    def find_dsl_caller(block)
      receiver = block.binding.receiver
      receiver.is_a?(DslBlock) ? receiver.dsl_caller : receiver
    end

    def method_missing(name, ...)
      raise(NoMethodError.new(caller_method_message(name), name, receiver: self)) if dsl_caller&.respond_to?(name, true)

      super
    end

    def respond_to_missing?(name, include_private = false) = super

    def caller_method_message(name)
      <<~MSG.tr("\n", " ").strip
        undefined method '#{name}' for #{self.class}. #{dsl_caller.class} defines '#{name}',
        but a SlackLine block with no arguments runs with the builder as self, so
        your own methods and instance variables aren't available inside it. Give the
        block an argument to keep them, like `do |m| m.text ... end`.
      MSG
    end
  end
end
