RSpec.describe SlackLine::SentThread do
  let(:sent_message_one) { instance_double(SlackLine::SentMessage, channel: "C12345678", ts: "1234567890.123456") }
  let(:sent_message_two) { instance_double(SlackLine::SentMessage, channel: "C12345678", ts: "1234567891.654321") }
  let(:sent_message_tre) { instance_double(SlackLine::SentMessage, channel: "C12345678", ts: "1234567894.111111") }
  let(:sent_messages) { [sent_message_one, sent_message_two, sent_message_tre] }

  subject(:sent_thread) { described_class.new(sent_message_one, sent_message_two, sent_message_tre) }

  it { is_expected.to have_attributes(messages: sent_messages, sent_messages:) }
  it { is_expected.to have_attributes(channel: "C12345678", ts: "1234567890.123456", thread_ts: "1234567890.123456") }

  it "behaves like an Enumerable" do
    expect(sent_thread.size).to eq(3)
    expect(sent_thread.first).to be(sent_message_one)
    expect(sent_thread.last).to be(sent_message_tre)
    expect(sent_thread.map(&:ts)).to eq(["1234567890.123456", "1234567891.654321", "1234567894.111111"])

    expect(sent_thread.map(&:ts)).to eq(sent_messages.map(&:ts))
    total_size = sent_thread.reduce(0) { |sum, sm| sum + sm.ts.length }
    expect(total_size).to eq(sent_messages.map(&:ts).map(&:length).sum)
  end

  describe "#inspect" do
    subject(:inspect_output) { sent_thread.inspect }

    it "includes class name, channel, size, and thread_ts" do
      expect(inspect_output).to eq('#<SlackLine::SentThread channel="C12345678" size=3 thread_ts="1234567890.123456">')
    end
  end
end
