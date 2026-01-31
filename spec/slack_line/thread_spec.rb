RSpec.describe SlackLine::Thread do
  let(:configuration) { instance_double(SlackLine::Configuration, default_channel: "#default") }
  let(:slack_client) { instance_double(Slack::Web::Client) }
  let(:client) { instance_double(SlackLine::Client, configuration:, slack_client:) }

  it "raises an ArgumentError when no message content is provided" do
    expect { described_class.new(client:) }
      .to raise_error(ArgumentError, "Provide either texts/blocks/Messages or a DSL block.")
  end

  it "raises an ArgumentError when both message contents and a DSL block are provided" do
    expect { described_class.new("Hello", client:) { text "World" } }
      .to raise_error(ArgumentError, "Provide either texts/blocks/Messages or a DSL block, not both.")
  end

  it "raises an ArgumentError when an invalid message type is provided" do
    expect { described_class.new("hi", 3.14, client:) }
      .to raise_error(ArgumentError, /Invalid message type: Float/)
  end

  it "handles a supplied dsl-block" do
    thread = described_class.new(client:) do
      message "First message from DSL"
      message do
        text "Second message from DSL", plain: true
      end
      text "Third message from DSL"
    end

    expect(thread.messages.size).to eq(3)
    expect(thread.messages).to all(be_a(SlackLine::Message))
    expect(thread.messages[0].content.as_json).to eq([{text: {text: "First message from DSL", type: "mrkdwn"}, type: "section"}])
    expect(thread.messages[1].content.as_json).to eq([{text: {text: "Second message from DSL", type: "plain_text"}, type: "section"}])
    expect(thread.messages[2].content.as_json).to eq([{text: {text: "Third message from DSL", type: "mrkdwn"}, type: "section"}])
  end

  it "handles a supplied String message" do
    thread = described_class.new("Hello, world!", client:)

    expect(thread.messages.size).to eq(1)
    expect(thread.messages[0]).to be_a(SlackLine::Message)
    expect(thread.messages[0].content.as_json).to eq([{text: {text: "Hello, world!", type: "mrkdwn"}, type: "section"}])
  end

  it "handles a supplied Slack::BlockKit::Blocks message" do
    blocks = Slack::BlockKit.blocks { |b| b.section { |s| s.mrkdwn(text: "Block message") } }
    thread = described_class.new(blocks, client:)

    expect(thread.messages.size).to eq(1)
    expect(thread.messages[0]).to be_a(SlackLine::Message)
    expect(thread.messages[0].content.as_json).to eq([{text: {text: "Block message", type: "mrkdwn"}, type: "section"}])
  end

  it "handles a supplied SlackLine::Message message" do
    message = SlackLine::Message.new("Prebuilt message", client:)
    thread = described_class.new(message, client:)

    expect(thread.messages.size).to eq(1)
    expect(thread.messages[0]).to be(message)
    expect(thread.messages[0].content.as_json).to eq([{text: {text: "Prebuilt message", type: "mrkdwn"}, type: "section"}])
  end

  it "handles supplied mixed message types" do
    prebuilt_message = SlackLine::Message.new("Prebuilt message", client:)
    blocks = Slack::BlockKit.blocks { |b| b.section { |s| s.mrkdwn(text: "Block message") } }
    thread = described_class.new("String message", blocks, prebuilt_message, client:)

    expect(thread.messages.size).to eq(3)
    expect(thread.messages).to all(be_a(SlackLine::Message))

    expect(thread.messages[0].content.as_json).to eq([{text: {text: "String message", type: "mrkdwn"}, type: "section"}])
    expect(thread.messages[1].content.as_json).to eq([{text: {text: "Block message", type: "mrkdwn"}, type: "section"}])
    expect(thread.messages[2]).to be(prebuilt_message)
    expect(thread.messages[2].content.as_json).to eq([{text: {text: "Prebuilt message", type: "mrkdwn"}, type: "section"}])
  end

  describe "#builder_urls" do
    let(:thread) { described_class.new("First message", "Second message", client:) }
    subject(:builder_urls) { thread.builder_urls }

    it { is_expected.to be_a(Array) }
    it { is_expected.to have_attributes(size: 2) }
    it { is_expected.to all(be_a(String)) }
    it { is_expected.to all(start_with("https://app.slack.com/block-kit-builder#")) }
  end

  describe "#post" do
    let(:message_one) { SlackLine::Message.new("First message", client:) }
    let(:message_two) { SlackLine::Message.new("Second message", client:) }
    let(:message_tre) { SlackLine::Message.new("Third message", client:) }
    let(:thread) { described_class.new(message_one, message_two, message_tre, client:) }
    subject(:post) { thread.post(to: target_channel) }

    before do
      allow(slack_client).to receive(:chat_postMessage).and_return(
        Slack::Messages::Message.new(ts: "111.111", channel: "C12345678"),
        Slack::Messages::Message.new(ts: "222.222", channel: "C12345678"),
        Slack::Messages::Message.new(ts: "333.333", channel: "C12345678")
      )
    end

    context "when a target channel is provided" do
      let(:target_channel) { "#custom-channel" }

      it "makes the expected message posts to Slack" do
        post
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: target_channel, blocks: message_one.content.as_json, thread_ts: nil).ordered
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: target_channel, blocks: message_two.content.as_json, thread_ts: "111.111").ordered
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: target_channel, blocks: message_tre.content.as_json, thread_ts: "111.111").ordered
      end

      it "produces the expected SentThread" do
        sent_thread = post
        expect(sent_thread).to be_a(SlackLine::SentThread)
        expect(sent_thread.messages).to all(be_a(SlackLine::SentMessage))
        expect(sent_thread.size).to eq(3)

        expect(sent_thread.to_a[0]).to have_attributes(ts: "111.111", channel: "C12345678")
        expect(sent_thread.to_a[1]).to have_attributes(ts: "222.222", channel: "C12345678")
        expect(sent_thread.to_a[2]).to have_attributes(ts: "333.333", channel: "C12345678")
      end
    end

    context "when a target channel is not provided" do
      let(:target_channel) { nil }

      it "uses the default channel from configuration" do
        post
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: configuration.default_channel, blocks: anything, thread_ts: anything)
          .exactly(3).times
      end

      context "and no default channel is configured" do
        before { allow(configuration).to receive(:default_channel).and_return(nil) }

        it "raises a ConfigurationError" do
          expect { post }
            .to raise_error(SlackLine::ConfigurationError, "No target channel specified and no default_channel configured.")
        end
      end
    end
  end
end
