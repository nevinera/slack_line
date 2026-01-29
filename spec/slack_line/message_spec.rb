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
    message = described_class.new(nil, client:) { text "Hello from DSL" }
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
end
