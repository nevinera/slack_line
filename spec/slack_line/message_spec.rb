RSpec.describe SlackLine::Message do
  let(:client) { instance_double(SlackLine::Client) }

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
end
