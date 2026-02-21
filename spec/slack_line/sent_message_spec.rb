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

  describe "#thread_from" do
    let(:configuration) { instance_double(SlackLine::Configuration, bot_name: "TestBot") }
    let(:client) { instance_double(SlackLine::Client, slack_client:, configuration:) }
    let(:new_response) { Slack::Messages::Message.new({ts: "9999999999.000001", channel: "C12345678"}) }

    before { allow(slack_client).to receive(:chat_postMessage).and_return(new_response) }

    context "when appending with a string" do
      subject(:result) { sent_message.thread_from("Reply message") }

      it "returns a SentThread starting with the original message" do
        expect(result).to be_a(SlackLine::SentThread)
        expect(result.first).to be(sent_message)
      end

      it "posts the reply with the correct thread_ts and channel" do
        result
        blocks = [{type: "section", text: {type: "mrkdwn", text: "Reply message"}}]
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "C12345678", blocks:, thread_ts: "1234567890.123456", username: "TestBot")
      end

      it "includes the new sent message in the returned thread" do
        expect(result.size).to eq(2)
        expect(result.last).to be_a(SlackLine::SentMessage)
        expect(result.last.ts).to eq("9999999999.000001")
      end
    end

    context "when appending with a DSL block" do
      subject(:result) { sent_message.thread_from { text "DSL reply" } }

      it "returns a SentThread with the original message and new reply" do
        expect(result.size).to eq(2)
        expect(result.first).to be(sent_message)
      end

      it "posts the reply with the correct thread_ts" do
        result
        blocks = [{type: "section", text: {type: "mrkdwn", text: "DSL reply"}}]
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "C12345678", blocks:, thread_ts: "1234567890.123456", username: "TestBot")
      end
    end

    context "when appending with a Message object" do
      let(:message) { SlackLine::Message.new("Message reply", client:) }
      subject(:result) { sent_message.thread_from(message) }

      it "posts the reply with the correct thread_ts and channel" do
        result
        blocks = [{type: "section", text: {type: "mrkdwn", text: "Message reply"}}]
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "C12345678", blocks:, thread_ts: "1234567890.123456", username: "TestBot")
      end
    end

    context "when the message is itself a reply" do
      let(:response) { Slack::Messages::Message.new({ts: "1234567891.000001", channel: "C12345678", thread_ts: "1234567890.123456"}) }
      subject(:result) { sent_message.thread_from("Another reply") }

      it "posts to the root thread_ts, not the reply's own ts" do
        result
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "C12345678", blocks: anything, thread_ts: "1234567890.123456", username: "TestBot")
      end
    end
  end

  describe "#as_json" do
    subject(:json) { sent_message.as_json }

    it "returns a hash with type 'message' and all necessary fields" do
      expect(json).to eq(
        "type" => "message",
        "ts" => "1234567890.123456",
        "channel" => "C12345678",
        "thread_ts" => nil,
        "content" => content,
        "priorly" => nil
      )
    end

    context "when the message is a reply" do
      let(:response) { Slack::Messages::Message.new({ts: "1234567891.000001", channel: "C12345678", thread_ts: "1234567890.123456"}) }

      it "includes the root thread_ts" do
        expect(json["thread_ts"]).to eq("1234567890.123456")
      end
    end

    context "when priorly is present" do
      let(:priorly) { [{type: "section", text: {type: "mrkdwn", text: "Previous"}}] }

      it "includes priorly" do
        expect(json["priorly"]).to eq(priorly)
      end
    end
  end

  describe ".from_json" do
    subject(:loaded) { described_class.from_json(sent_message.as_json, client:) }

    it "restores ts, channel, content, and priorly" do
      expect(loaded).to have_attributes(
        ts: "1234567890.123456",
        channel: "C12345678",
        content: content,
        priorly: nil
      )
    end

    it "restores thread_ts as the message's own ts for a root message" do
      expect(loaded.thread_ts).to eq("1234567890.123456")
    end

    context "when restoring a reply message" do
      let(:response) { Slack::Messages::Message.new({ts: "1234567891.000001", channel: "C12345678", thread_ts: "1234567890.123456"}) }

      it "preserves the root thread_ts" do
        expect(loaded.ts).to eq("1234567891.000001")
        expect(loaded.thread_ts).to eq("1234567890.123456")
      end
    end

    context "when priorly is present" do
      let(:priorly) { [{type: "section", text: {type: "mrkdwn", text: "Previous"}}] }

      it "restores priorly" do
        expect(loaded.priorly).to eq(priorly)
      end
    end

    context "when the type key is wrong" do
      subject(:loaded) { described_class.from_json({"type" => "thread"}, client:) }

      it "raises ArgumentError" do
        expect { loaded }.to raise_error(ArgumentError, /Expected type 'message'/)
      end
    end

    context "when the type key is missing" do
      subject(:loaded) { described_class.from_json({}, client:) }

      it "raises ArgumentError" do
        expect { loaded }.to raise_error(ArgumentError, /Expected type 'message'/)
      end
    end

    context "after a full JSON round-trip (generate + parse)" do
      subject(:loaded) { described_class.from_json(JSON.parse(JSON.generate(sent_message.as_json)), client:) }

      it "preserves channel" do
        expect(loaded.channel).to eq("C12345678")
      end

      it "preserves content with string keys" do
        expect(loaded.content).to eq([{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hello"}}])
      end
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
