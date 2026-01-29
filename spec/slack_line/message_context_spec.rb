RSpec.describe SlackLine::MessageContext do
  describe "DSL" do
    it "builds a complex slack message" do
      mc = described_class.new do
        context "This is a context"
        text "Initial _text_"
        divider
        section do
          text "More text", plain: true
          text "even _more_ text"
          link "Go here", "https://example.com"
        end
      end

      expect(mc.content.as_json).to eq([
        {type: "context", elements: [{type: "mrkdwn", text: "This is a context"}]},
        {type: "section", text: {type: "mrkdwn", text: "Initial _text_"}},
        {type: "divider"},
        {
          type: "section",
          text: {type: "mrkdwn", text: "even _more_ text"},
          accessory: {
            type: "button",
            text: {type: "plain_text", text: "Go here"},
            action_id: "link-button",
            url: "https://example.com"
          }
        }
      ])
    end

    it "has access to the containing scope" do
      my_text = "externally defined"
      expect(described_class.new { text my_text }.content.as_json)
        .to eq([{type: "section", text: {type: "mrkdwn", text: "externally defined"}}])
    end

    it "handles a mrkdwn text call properly" do
      expect(described_class.new { text "Hello _world_" }.content.as_json)
        .to eq([{type: "section", text: {type: "mrkdwn", text: "Hello _world_"}}])
    end

    it "handles plain text call properly" do
      expect(described_class.new { text "Hello world", plain: true }.content.as_json)
        .to eq([{type: "section", text: {type: "plain_text", text: "Hello world"}}])
    end

    it "handles a divider call properly" do
      expect(described_class.new { divider }.content.as_json)
        .to eq([{type: "divider"}])
    end

    it "handles a mrkdwn context call properly" do
      expect(described_class.new { context "Context _here_" }.content.as_json)
        .to eq([{type: "context", elements: [{type: "mrkdwn", text: "Context _here_"}]}])
    end

    it "handles a plain text context call properly" do
      expect(described_class.new { context "Context here", plain: true }.content.as_json)
        .to eq([{type: "context", elements: [{type: "plain_text", text: "Context here"}]}])
    end

    it "handles a section call as expected" do
      expect(described_class.new { section { text "Section _text_" } }.content.as_json)
        .to eq([{type: "section", text: {type: "mrkdwn", text: "Section _text_"}}])
    end
  end
end
