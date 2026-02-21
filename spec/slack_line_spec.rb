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

  describe ".from_json" do
    let(:client) { instance_double(SlackLine::Client) }
    let(:message_data) { {"type" => "message", "ts" => "1234567890.123456", "channel" => "C12345678", "thread_ts" => nil, "content" => [], "priorly" => nil} }
    let(:thread_data) do
      {"type" => "thread", "messages" => [
        {"type" => "message", "ts" => "1234567890.123456", "channel" => "C12345678", "thread_ts" => nil, "content" => [], "priorly" => nil}
      ]}
    end

    it "loads a SentMessage when type is 'message'" do
      expect(described_class.from_json(message_data, client:)).to be_a(SlackLine::SentMessage)
    end

    it "loads a SentThread when type is 'thread'" do
      expect(described_class.from_json(thread_data, client:)).to be_a(SlackLine::SentThread)
    end

    it "raises ArgumentError for an unknown type" do
      expect { described_class.from_json({"type" => "bogus"}, client:) }
        .to raise_error(ArgumentError, /Unknown type/)
    end

    it "raises ArgumentError when type is missing" do
      expect { described_class.from_json({}, client:) }
        .to raise_error(ArgumentError, /Unknown type/)
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
