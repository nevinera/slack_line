RSpec.describe SlackLine::SentMessage do
  let(:content) { [type: "section", text: {type: "mrkdwn", text: "Hello"}] }
  let(:priorly) { nil }
  let(:response) { Slack::Messages::Message.new({ts: "1234567890.123456", channel: "C12345678"}) }
  let(:client) { instance_double(SlackLine::Client) }
  subject(:sent_message) { described_class.new(content:, priorly:, response:, client:) }

  it { is_expected.to have_attributes(content:, response:, priorly: nil) }
  it { is_expected.to have_attributes(ts: "1234567890.123456", channel: "C12345678") }

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
end
