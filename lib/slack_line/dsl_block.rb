module SlackLine
  # Runs a DSL block against a builder. A block that takes no arguments runs
  # with the builder as self; a block that takes an argument receives the
  # builder instead, so the caller keeps its own methods and instance variables.
  module DslBlock
    private

    def run_dsl_block(block) = block.arity.zero? ? instance_exec(&block) : block.call(self)
  end
end
