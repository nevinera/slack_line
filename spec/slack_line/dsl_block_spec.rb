RSpec.describe SlackLine::DslBlock do
  let(:notifier_class) do
    Class.new do
      def bare_message = SlackLine::MessageContext.new { text problems_path }

      def bare_section = SlackLine::MessageContext.new { section { link "Go", problems_path } }

      def bare_thread = SlackLine::ThreadContext.new { message { text problems_path } }

      def unknown_in_bare_block = SlackLine::MessageContext.new { text not_defined_anywhere }

      def unknown_in_argument_block = SlackLine::MessageContext.new { |m| m.to_a }

      private

      def problems_path = "https://example.com/problems"
    end
  end

  let(:notifier) { notifier_class.new }

  before { stub_const("ProblemNotifier", notifier_class) }

  shared_examples "an explained caller method" do |builder_class|
    it "explains that the caller's method isn't available" do
      expect(&build).to raise_error(NoMethodError) { |e|
        expect(e.name).to eq(:problems_path)
        expect(e.message).to start_with("undefined method 'problems_path' for #{builder_class}.")
        expect(e.message).to include("ProblemNotifier defines 'problems_path'")
        expect(e.message).to include("Give the block an argument")
      }
    end
  end

  context "when a bare message block calls a caller method" do
    let(:build) { -> { notifier.bare_message } }

    it_behaves_like "an explained caller method", SlackLine::MessageContext
  end

  context "when a bare section block nested in a bare message block calls a caller method" do
    let(:build) { -> { notifier.bare_section } }

    it_behaves_like "an explained caller method", SlackLine::SectionContext
  end

  context "when a bare message block nested in a bare thread block calls a caller method" do
    let(:build) { -> { notifier.bare_thread } }

    it_behaves_like "an explained caller method", SlackLine::MessageContext
  end

  it "raises the usual NameError for a method the caller lacks too" do
    expect { notifier.unknown_in_bare_block }.to raise_error(NameError) { |e|
      expect(e.name).to eq(:not_defined_anywhere)
      expect(e.message).not_to include("Give the block an argument")
    }
  end

  it "raises the usual NoMethodError when a block that takes an argument calls a missing builder method" do
    expect { notifier.unknown_in_argument_block }.to raise_error(NoMethodError) { |e|
      expect(e.name).to eq(:to_a)
      expect(e.message).not_to include("Give the block an argument")
    }
  end

  it "doesn't make the builder respond to the caller's methods" do
    expect(SlackLine::MessageContext.new { nil }.respond_to?(:problems_path, true)).to be(false)
  end
end
