RSpec.describe SlackLine::SectionContext do
  describe "DSL" do
    around do |example|
      Slack::BlockKit.blocks do |b|
        @parent_context = b
        example.run
      ensure
        @parent_context = nil
      end
    end

    it "builds a complex section" do
      sc = described_class.new(@parent_context) do
        text "Section _text_"
        link "Click here", "https://example.com"
      end

      expect(sc.content.as_json).to eq([{
        type: "section",
        text: {type: "mrkdwn", text: "Section _text_"},
        accessory: {
          type: "button",
          text: {type: "plain_text", text: "Click here"},
          action_id: "link-button",
          url: "https://example.com"
        }
      }])
    end

    it "has access to the containing scope" do
      my_text = "externally defined in section"
      expect(described_class.new(@parent_context) { text my_text }.content.as_json)
        .to eq([{type: "section", text: {type: "mrkdwn", text: "externally defined in section"}}])
    end

    describe "#text" do
      it "handles plain text properly" do
        expect(described_class.new(@parent_context) { text "Plain text here", plain: true }.content.as_json)
          .to eq([{type: "section", text: {type: "plain_text", text: "Plain text here"}}])
      end

      it "handles mrkdwn text properly" do
        expect(described_class.new(@parent_context) { text "Markdown _text_" }.content.as_json)
          .to eq([{type: "section", text: {type: "mrkdwn", text: "Markdown _text_"}}])
      end
    end

    describe "#link" do
      it "handles a link properly" do
        expect(described_class.new(@parent_context) { link "Go", "https://example.com" }.content.as_json).to eq([{
          type: "section",
          accessory: {
            type: "button",
            text: {type: "plain_text", text: "Go"},
            action_id: "link-button",
            url: "https://example.com"
          }
        }])
      end
    end
  end
end
