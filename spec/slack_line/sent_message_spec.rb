RSpec.describe SlackLine::SentMessage do
  let(:content) { [type: "section", text: {type: "mrkdwn", text: "Hello"}] }
  let(:priorly) { nil }
  let(:response) { Slack::Messages::Message.new({ts: "1234567890.123456", channel: "C12345678"}) }
  let(:client) { instance_double(SlackLine::Client, slack_client:) }
  let(:slack_client) { instance_double(Slack::Web::Client) }
  subject(:sent_message) { described_class.new(content:, priorly:, response:, client:) }

  it { is_expected.to have_attributes(content:, response:, priorly: nil) }
  it { is_expected.to have_attributes(ts: "1234567890.123456", channel: "C12345678") }

  describe "#thread_ts" do
    context "when the message is a root message (no thread_ts in response)" do
      it "returns the message's own ts" do
        expect(sent_message.thread_ts).to eq("1234567890.123456")
      end
    end

    context "when the message is a reply (thread_ts present in response)" do
      let(:response) { Slack::Messages::Message.new({ts: "1234567891.000001", channel: "C12345678", thread_ts: "1234567890.123456"}) }

      it "returns the root message's thread_ts" do
        expect(sent_message.thread_ts).to eq("1234567890.123456")
      end
    end
  end

  context "when prior content is supplied" do
    let(:priorly) { [type: "section", text: {type: "mrkdwn", text: "Previous message"}] }

    it { is_expected.to have_attributes(content:, priorly:) }
  end

  describe "#inspect" do
    subject(:inspect_output) { sent_message.inspect }

    it "includes class name, channel, and ts" do
      expect(inspect_output).to eq('#<SlackLine::SentMessage channel="C12345678" ts="1234567890.123456">')
    end
  end

  describe "#update" do
    let(:response) { Slack::Messages::Message.new({ts: "1234567890.123456", channel: "C12345678"}) }
    before { allow(slack_client).to receive(:chat_update).and_return(response) }

    context "when updating with a string" do
      subject(:updated_message) { sent_message.update("replacement") }

      it "performs the intended API update" do
        updated_message
        blocks = [{type: "section", text: {type: "mrkdwn", text: "replacement"}}]
        expect(slack_client).to have_received(:chat_update).with(channel: "C12345678", ts: "1234567890.123456", blocks:)
      end

      it "returns the expected SentMessage" do
        expect(updated_message).to be_a(SlackLine::SentMessage)
        expect(updated_message).to have_attributes(
          content: [{type: "section", text: {type: "mrkdwn", text: "replacement"}}],
          priorly: sent_message.content,
          ts: "1234567890.123456",
          channel: "C12345678"
        )
      end
    end

    context "when updating with multiple strings" do
      subject(:updated_message) { sent_message.update("First line", "Second line") }

      it "performs the intended API update" do
        updated_message
        blocks = [
          {type: "section", text: {type: "mrkdwn", text: "First line"}},
          {type: "section", text: {type: "mrkdwn", text: "Second line"}}
        ]
        expect(slack_client).to have_received(:chat_update).with(channel: "C12345678", ts: "1234567890.123456", blocks:)
      end

      it "returns the expected SentMessage" do
        expect(updated_message).to be_a(SlackLine::SentMessage)
        expect(updated_message).to have_attributes(
          content: [
            {type: "section", text: {type: "mrkdwn", text: "First line"}},
            {type: "section", text: {type: "mrkdwn", text: "Second line"}}
          ],
          priorly: sent_message.content,
          ts: "1234567890.123456",
          channel: "C12345678"
        )
      end
    end

    context "when updating with a DSL block" do
      subject(:updated_message) { sent_message.update { text "Updated _content_" } }

      it "performs the intended API update" do
        updated_message
        blocks = [{type: "section", text: {type: "mrkdwn", text: "Updated _content_"}}]
        expect(slack_client).to have_received(:chat_update).with(channel: "C12345678", ts: "1234567890.123456", blocks:)
      end

      it "returns the expected SentMessage" do
        expect(updated_message).to be_a(SlackLine::SentMessage)
        expect(updated_message).to have_attributes(
          content: [{type: "section", text: {type: "mrkdwn", text: "Updated _content_"}}],
          priorly: sent_message.content,
          ts: "1234567890.123456",
          channel: "C12345678"
        )
      end
    end

    context "when updating with BlockKit data" do
      let(:new_blocks) { Slack::BlockKit.blocks { |b| b.section { |s| s.mrkdwn(text: "Updated content via BlockKit") } } }
      subject(:updated_message) { sent_message.update(new_blocks) }

      it "performs the intended API update" do
        updated_message
        blocks = [{type: "section", text: {type: "mrkdwn", text: "Updated content via BlockKit"}}]
        expect(slack_client).to have_received(:chat_update).with(channel: "C12345678", ts: "1234567890.123456", blocks:)
      end

      it "returns the expected SentMessage" do
        expect(updated_message).to be_a(SlackLine::SentMessage)
        expect(updated_message).to have_attributes(
          content: [{type: "section", text: {type: "mrkdwn", text: "Updated content via BlockKit"}}],
          priorly: sent_message.content,
          ts: "1234567890.123456",
          channel: "C12345678"
        )
      end
    end
  end
end
