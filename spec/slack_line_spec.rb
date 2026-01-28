RSpec.describe SlackLine do
  describe ".configure" do
    # yes, mocking the class under test is gross. But this is much simpler than
    # the alternatives.
    before { allow(SlackLine).to receive(:configuration).and_return(temp_config) }

    let(:temp_config) { SlackLine::Configuration.new }

    it "exposes the configuration object to the block", :aggregate_failures do
      described_class.configure do |config|
        expect(config).to be(temp_config)
        config.bot_name = "TestBot"
      end

      expect(described_class.configuration.bot_name).to eq("TestBot")
    end
  end

  describe ".configuration" do
    subject(:configuration) { described_class.configuration }

    it { is_expected.to be_a(described_class::Configuration) }

    it "returns the same instance on multiple calls" do
      expect(configuration).to be(described_class.configuration)
    end
  end
end
