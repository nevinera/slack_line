RSpec.describe SlackLine do
  # Yes, mocking the class under test is gross. But this is much simpler than
  # the alternatives.

  describe ".configure" do
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

  describe ".client" do
    subject(:client) { described_class.client }

    before { allow(SlackLine).to receive(:configuration).and_return(temp_config) }

    let(:temp_config) { SlackLine::Configuration.new(slack_token: "foo-token") }

    it { is_expected.to be_a(described_class::Client) }

    it "returns the same instance on multiple calls" do
      expect(client).to be(described_class.client)
    end
  end

  describe "forwarded methods" do
    let(:mock_client) { instance_double(SlackLine::Client, message: nil, thread: nil) }

    before { allow(SlackLine).to receive(:client).and_return(mock_client) }

    it "forwards those module methods to the singleton client" do
      SlackLine.message("Hello")
      expect(mock_client).to have_received(:message).with("Hello")

      SlackLine.thread("Thread start")
      expect(mock_client).to have_received(:thread).with("Thread start")
    end
  end
end
