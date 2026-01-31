RSpec.describe SlackLine::SentMessage do
  let(:original_content) { [type: "section", text: {type: "mrkdwn", text: "Hello"}] }
  let(:response) { Slack::Messages::Message.new({ts: "1234567890.123456", channel: "C12345678"}) }
  subject(:sent_message) { described_class.new(original_content: original_content, response: response) }

  it { is_expected.to have_attributes(original_content:, response:) }
  it { is_expected.to have_attributes(ts: "1234567890.123456", channel: "C12345678") }

  describe "#inspect" do
    subject(:inspect_output) { sent_message.inspect }

    it "includes class name, channel, and ts" do
      expect(inspect_output).to eq('#<SlackLine::SentMessage channel="C12345678" ts="1234567890.123456">')
    end
  end
end
