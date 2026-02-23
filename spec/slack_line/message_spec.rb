RSpec.describe SlackLine::Message do
  let(:configuration) { instance_double(SlackLine::Configuration, default_channel: "#default", bot_name: "TestBot", backoff: true) }
  let(:slack_client) { instance_double(Slack::Web::Client) }
  let(:client) { instance_double(SlackLine::Client, configuration:, slack_client:) }

  it "raises an ArgumentError when both text/blocks and a DSL block are provided" do
    expect { described_class.new("Hello", client:) { text "Goodbye" } }
      .to raise_error(ArgumentError, /not both/)
  end

  it "raises an ArgumentError when neither text/blocks nor a DSL block is provided" do
    expect { described_class.new(nil, client:) }
      .to raise_error(ArgumentError, /Provide either/)
  end

  it "raises an ArgumentError when an invalid content type is provided" do
    expect { described_class.new(42, client:) }
      .to raise_error(ArgumentError, /Invalid content type/)
  end

  it "creates content from a DSL block when provided" do
    message = described_class.new(client:) { text "Hello from DSL" }
    expect(message).to be_a(SlackLine::Message)
    expect(message.content).to be_a(Slack::BlockKit::Blocks)
    expect(message.content.as_json).to eq([{
      text: {text: "Hello from DSL", type: "mrkdwn"},
      type: "section"
    }])
  end

  it "creates content from a text string when provided" do
    message = described_class.new("Hello, world!", client:)
    expect(message).to be_a(SlackLine::Message)
    expect(message.content).to be_a(Slack::BlockKit::Blocks)
    expect(message.content.as_json).to eq([{
      text: {text: "Hello, world!", type: "mrkdwn"},
      type: "section"
    }])
  end

  it "creates content from multiple text strings when provided" do
    message = described_class.new("Hello,", "world!", client:)
    expect(message).to be_a(SlackLine::Message)
    expect(message.content).to be_a(Slack::BlockKit::Blocks)
    expect(message.content.as_json).to eq([
      {text: {text: "Hello,", type: "mrkdwn"}, type: "section"},
      {text: {text: "world!", type: "mrkdwn"}, type: "section"}
    ])
  end

  it "creates content from Slack::BlockKit::Blocks when provided" do
    blocks = Slack::BlockKit.blocks { |b| b.section { |s| s.mrkdwn(text: "Predefined block") } }
    message = described_class.new(blocks, client:)
    expect(message).to be_a(SlackLine::Message)
    expect(message.content).to be(blocks)
    expect(message.content.as_json).to eq([{
      text: {text: "Predefined block", type: "mrkdwn"},
      type: "section"
    }])
  end

  it "rejects multiple Slack::BlockKit::Blocks as content" do
    blocks1 = Slack::BlockKit.blocks { |b| b.section { |s| s.mrkdwn(text: "Block 1") } }
    blocks2 = Slack::BlockKit.blocks { |b| b.section { |s| s.mrkdwn(text: "Block 2") } }
    expect { described_class.new(blocks1, blocks2, client:) }
      .to raise_error(ArgumentError, /Invalid content type/)
  end

  describe "#builder_url" do
    let(:message) { described_class.new("Test message", client:) }
    subject(:builder_url) { message.builder_url }

    it { is_expected.to be_a(String) }
    it { is_expected.to start_with("https://app.slack.com/block-kit-builder#") }
    it { is_expected.to end_with(CGI.escape({blocks: message.content.as_json}.to_json)) }
  end

  describe "#post" do
    let(:message) { described_class.new("Hello, Slack!", client:) }
    let(:target) { "#bot-testing" }
    let(:thread_ts) { nil }
    subject(:post) { message.post(to: target, thread_ts:) }

    let(:response) { Slack::Messages::Message.new({ok: true, ts: "1234567890.123456", channel: "C12345678"}) }
    before { allow(slack_client).to receive(:chat_postMessage).and_return(response) }

    let(:default_channel) { "#bot-default" }
    before { allow(configuration).to receive(:default_channel).and_return(default_channel) }

    context "with no target specified" do
      let(:target) { nil }

      it "performs the expected postMessage API call" do
        post
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "#bot-default", blocks: message.content.as_json, thread_ts: nil, username: "TestBot")
      end

      it "produces the expected SentMessage" do
        sent_message = post
        expect(sent_message).to be_a(SlackLine::SentMessage)
        expect(sent_message).to have_attributes(
          content: message.content.as_json,
          response: response,
          ts: "1234567890.123456",
          channel: "C12345678"
        )
      end

      context "and no default channel configured" do
        let(:default_channel) { nil }

        it "raises a ConfigurationError" do
          expect { post }.to raise_error(SlackLine::ConfigurationError, /No target channel specified/)
        end
      end
    end

    context "with a target specified" do
      let(:target) { "#bot-testing" }

      it "performs the expected postMessage API call" do
        post
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "#bot-testing", blocks: message.content.as_json, thread_ts: nil, username: "TestBot")
      end

      it "produces the expected SentMessage" do
        sent_message = post
        expect(sent_message).to be_a(SlackLine::SentMessage)
        expect(sent_message).to have_attributes(
          content: message.content.as_json,
          response: response,
          ts: "1234567890.123456",
          channel: "C12345678"
        )
      end
    end

    context "with a thread_ts supplied" do
      let(:thread_ts) { "1234567890.123456" }

      it "includes the thread_ts in the postMessage API call" do
        post
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: target, blocks: message.content.as_json, thread_ts: "1234567890.123456", username: "TestBot")
      end

      it "produces the expected SentMessage" do
        sent_message = post
        expect(sent_message).to be_a(SlackLine::SentMessage)
        expect(sent_message).to have_attributes(
          content: message.content.as_json,
          response: response,
          ts: "1234567890.123456",
          channel: "C12345678"
        )
      end
    end
  end
end
