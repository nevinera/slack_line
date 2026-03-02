RSpec.describe SlackLine::MessageConverter do
  let(:alice) { Slack::Messages::Message.new(id: "U001", profile: {display_name: "alice"}) }
  let(:eng) { Slack::Messages::Message.new(id: "S001", handle: "engineering") }

  let(:users) { instance_double(SlackLine::Users, find: nil) }
  let(:groups) { instance_double(SlackLine::Groups, find: nil) }
  let(:client) { instance_double(SlackLine::Client, users:, groups:) }

  before do
    allow(users).to receive(:find).with(display_name: "alice").and_return(alice)
    allow(groups).to receive(:find).with(handle: "engineering").and_return(eng)
  end

  subject(:converter) { described_class.new(blocks, client:) }

  describe "#convert" do
    context "with a simple mrkdwn text block" do
      let(:blocks) { [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hello @alice"}}] }

      it "replaces a known user mention" do
        expect(converter.convert).to eq(
          [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hello <@U001>"}}]
        )
      end
    end

    context "with a group mention" do
      let(:blocks) { [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hey @engineering"}}] }

      it "replaces a known group mention" do
        expect(converter.convert).to eq(
          [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hey <!subteam^S001>"}}]
        )
      end
    end

    context "with an unknown mention" do
      let(:blocks) { [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hello @nobody"}}] }

      it "leaves the token unchanged" do
        expect(converter.convert).to eq(
          [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hello @nobody"}}]
        )
      end
    end

    context "with multiple mentions in one string" do
      let(:blocks) { [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "@alice and @engineering and @nobody"}}] }

      it "replaces known mentions and leaves unknown ones alone" do
        expect(converter.convert).to eq(
          [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "<@U001> and <!subteam^S001> and @nobody"}}]
        )
      end
    end

    context "with multiple blocks" do
      let(:blocks) do
        [
          {"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hi @alice"}},
          {"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hello @nobody"}}
        ]
      end

      it "processes all blocks" do
        expect(converter.convert).to eq([
          {"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hi <@U001>"}},
          {"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Hello @nobody"}}
        ])
      end
    end

    context "with non-mrkdwn text fields" do
      let(:blocks) { [{"type" => "section", "text" => {"type" => "plain_text", "text" => "Hello @alice"}}] }

      it "leaves plain_text fields unchanged" do
        expect(converter.convert).to eq(
          [{"type" => "section", "text" => {"type" => "plain_text", "text" => "Hello @alice"}}]
        )
      end
    end

    context "with no mentions" do
      let(:blocks) { [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "Just a normal message"}}] }

      it "returns the blocks unchanged" do
        expect(converter.convert).to eq(blocks)
      end
    end
  end
end
