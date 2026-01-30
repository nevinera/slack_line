RSpec.describe SlackLine::Memoization do
  let(:test_class) do
    Class.new do
      include SlackLine::Memoization

      def initialize
        @call_count = 0
      end

      attr_reader :call_count
      memoize def compute_value = @call_count += 1
    end
  end

  it "caches the result of a method without arguments" do
    instance = test_class.new

    first_result = instance.compute_value
    second_result = instance.compute_value
    third_result = instance.compute_value

    expect(first_result).to eq(1)
    expect(second_result).to eq(1)
    expect(third_result).to eq(1)
    expect(instance.call_count).to eq(1)
  end

  it "raises an ArgumentError when trying to memoize a method with arguments" do
    bad_class = Class.new do
      include SlackLine::Memoization

      memoize def method_with_args(arg) = arg
    end

    expect { bad_class.new.method_with_args(42) }
      .to raise_error(ArgumentError, "Cannot memoize methods that take arguments")
  end
end
