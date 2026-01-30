module SlackLine
  module Memoization
    def self.included(base) = base.extend(ClassMethods)

    module ClassMethods
      def memoize(method_name)
        original_method = instance_method(method_name)

        define_method(method_name) do |*args|
          raise(ArgumentError, "Cannot memoize methods that take arguments") if args.any?

          @memoization_cache ||= {}

          if @memoization_cache.key?(method_name)
            @memoization_cache[method_name]
          else
            result = original_method.bind_call(self)
            @memoization_cache[method_name] = result
          end
        end
      end
    end
  end
end
