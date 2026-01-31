RSpec.describe SlackLine::Client do
  without_env("SLACK_LINE_SLACK_TOKEN")

  subject(:client) { described_class.new(nil, **overrides) }
  let(:overrides) { {slack_token: "fake-slack-token"} }

  context "when no slack_token is provided" do
    let(:overrides) { {} }

    it "raises an ArgumentError" do
      expect { client }.to raise_error(ArgumentError, "slack_token is required")
    end
  end

  describe "#configuration" do
    subject(:configuration) { client.configuration }

    it { is_expected.to be_a(SlackLine::Configuration) }
    it { is_expected.to have_attributes(slack_token: "fake-slack-token") }
  end

  describe "#message" do
    subject(:message) { client.message("Hello") }

    it { is_expected.to be_a(SlackLine::Message) }

    it "produces the expected content" do
      expect(message.content.as_json)
        .to eq([{text: {text: "Hello", type: "mrkdwn"}, type: "section"}])
    end

    it "supports multiple string arguments" do
      multi_message = client.message("Hello", "World")
      expect(multi_message.content.as_json).to eq([
        {text: {text: "Hello", type: "mrkdwn"}, type: "section"},
        {text: {text: "World", type: "mrkdwn"}, type: "section"}
      ])
    end
  end

  describe "#thread" do
    subject(:thread) { client.thread("Hi there", "Hello") }

    it { is_expected.to be_a(SlackLine::Thread) }

    it "contains the expected messages" do
      expect(thread.messages.size).to eq(2)
      expect(thread.messages).to all(be_a(SlackLine::Message))
      expect(thread.messages[0].content.as_json).to eq([{text: {text: "Hi there", type: "mrkdwn"}, type: "section"}])
      expect(thread.messages[1].content.as_json).to eq([{text: {text: "Hello", type: "mrkdwn"}, type: "section"}])
    end
  end
end
