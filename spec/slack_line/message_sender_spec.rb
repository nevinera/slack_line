RSpec.describe SlackLine::MessageSender do
  subject(:message_sender) { described_class.new(message:, client:, to:, thread_ts:) }

  let(:content) { Slack::BlockKit.blocks { |b| b.section { |s| s.mrkdwn(text: "Hello") } } }
  let(:message) { instance_double(SlackLine::Message, content:) }

  let(:response) { Slack::Messages::Message.new({ok: true, ts: "1234567890.123456", channel: "A1792321"}) }
  let(:slack_client) { instance_double(Slack::Web::Client, chat_postMessage: response) }
  let(:configuration) { instance_double(SlackLine::Configuration, default_channel: "#default", bot_name: "MyBot") }
  let(:users) { instance_double(SlackLine::Users) }
  let(:client) { instance_double(SlackLine::Client, configuration:, slack_client:, users:) }

  let(:to) { nil }
  let(:thread_ts) { nil }

  before { allow(slack_client).to receive(:chat_postMessage).and_return(response) }

  describe "#post" do
    subject(:sent_message) { message_sender.post }

    context "with no explicit 'to' parameter" do
      let(:to) { nil }

      it "sends the message to the correct channel" do
        sent_message
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "#default", blocks: content.as_json, thread_ts: nil, username: "MyBot")
      end
    end

    context "with an explicit 'to' parameter" do
      let(:to) { "#custom-channel" }

      it "sends the message to the correct channel" do
        sent_message
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "#custom-channel", blocks: content.as_json, thread_ts: nil, username: "MyBot")
      end
    end

    it "returns a SentMessage with the correct attributes" do
      expect(sent_message).to be_a(SlackLine::SentMessage)
      expect(sent_message.content).to eq(content.as_json)
      expect(sent_message.response).to eq(response)
    end

    context "when 'to' is a username" do
      let(:to) { "@alice" }
      let(:alice) { Hashie::Mash.new(id: "U12345", profile: {display_name: "alice"}) }
      let(:users) { instance_double(SlackLine::Users, find: alice) }

      it "resolves the username to a user ID and sends the message" do
        sent_message
        expect(users).to have_received(:find).with(display_name: "alice")
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "U12345", blocks: content.as_json, thread_ts: nil, username: "MyBot")
      end
    end
  end
end
