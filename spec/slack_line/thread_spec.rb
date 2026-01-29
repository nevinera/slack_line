RSpec.describe SlackLine::Thread do
  let(:client) { instance_double(SlackLine::Client) }

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
end
