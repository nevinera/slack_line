RSpec.describe SlackLine::ThreadContext do
  describe "#text" do
    it "handles a simple text message" do
      tc = described_class.new { message "Simple text message" }

      expect(tc.contents.size).to eq(1)
      expect(tc.contents[0]).to be_a(String)
      expect(tc.contents[0]).to eq("Simple text message")
    end

    it "raises ArgumentError when supplied with a non-string argument" do
      expect { described_class.new { message 12345 } }
        .to raise_error(ArgumentError, /String/)
    end
  end

  describe "#message" do
    it "handles a supplied String message" do
      tc = described_class.new { message "Another simple text message" }

      expect(tc.contents.size).to eq(1)
      expect(tc.contents[0]).to be_a(String)
      expect(tc.contents[0]).to eq("Another simple text message")
    end

    it "handles a supplied Slack::BlockKit::Blocks message" do
      blocks = Slack::BlockKit.blocks do |b|
        b.section { |s| s.mrkdwn(text: "Block message content") }
      end

      tc = described_class.new { message blocks }

      expect(tc.contents.size).to eq(1)
      expect(tc.contents[0]).to be_a(Slack::BlockKit::Blocks)
      expect(tc.contents[0].as_json).to eq([
        {type: "section", text: {type: "mrkdwn", text: "Block message content"}}
      ])
    end

    it "handles a supplied SlackLine::Message message" do
      client = instance_double(SlackLine::Client)
      built_message = SlackLine::Message.new("Message object content", client:)

      tc = described_class.new { message built_message }

      expect(tc.contents.size).to eq(1)
      expect(tc.contents[0]).to be(built_message)
    end

    it "handles a supplied DSL block message" do
      tc = described_class.new do
        message do
          text "DSL block message content"
          divider
        end
      end

      expect(tc.contents.size).to eq(1)
      expect(tc.contents[0]).to be_a(Slack::BlockKit::Blocks)
      expect(tc.contents[0].as_json).to eq([
        {type: "section", text: {type: "mrkdwn", text: "DSL block message content"}},
        {type: "divider"}
      ])
    end

    it "raises ArgumentError when supplied with an invalid message type" do
      expect { described_class.new { message 3.14 } }
        .to raise_error(ArgumentError, /String, Slack::BlockKit::Blocks, or SlackLine::Message/)
    end

    it "raises ArgumentError when both argument and DSL block are provided" do
      expect { described_class.new { message("Invalid") { text "Also invalid" } } }
        .to raise_error(ArgumentError, /either a supplied message or a message block, not both/)
    end

    it "raises ArgumentError when neither argument nor DSL block are provided" do
      expect { described_class.new { message } }
        .to raise_error(ArgumentError, /either a supplied message or a message block, not both/)
    end
  end

  describe "DSL" do
    let(:client) { instance_double(SlackLine::Client) }

    it "builds a complex thread of messages" do
      preconstructed_message = SlackLine::Message.new("Preconstructed", client:)
      tc = described_class.new do
        message "First message"
        message do
          text "Second message with _markdown_"
          divider
          text "End of second message", plain: true
        end

        message(preconstructed_message)
      end

      expect(tc.contents.size).to eq(3)
      expect(tc.contents[0]).to eq("First message")
      expect(tc.contents[1]).to be_a(Slack::BlockKit::Blocks)
      expect(tc.contents[1].as_json).to eq([
        {type: "section", text: {type: "mrkdwn", text: "Second message with _markdown_"}},
        {type: "divider"},
        {type: "section", text: {type: "plain_text", text: "End of second message"}}
      ])
      expect(tc.contents[2]).to be(preconstructed_message)
    end
  end
end
