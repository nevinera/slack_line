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

  describe "#append" do
    let(:new_message_one) { instance_double(SlackLine::SentMessage, channel: "C12345678", ts: "1234567895.000001") }
    let(:new_message_two) { instance_double(SlackLine::SentMessage, channel: "C12345678", ts: "1234567895.000002") }

    context "when appending with a string" do
      let(:extended) { described_class.new(sent_message_one, new_message_one) }
      before { allow(sent_message_one).to receive(:thread_from).with("New message").and_return(extended) }
      subject(:result) { sent_thread.append("New message") }

      it "delegates to first.thread_from" do
        result
        expect(sent_message_one).to have_received(:thread_from).with("New message")
      end

      it "returns a SentThread combining all original and new messages" do
        expect(result).to be_a(SlackLine::SentThread)
        expect(result.sent_messages).to eq([sent_message_one, sent_message_two, sent_message_tre, new_message_one])
      end
    end

    context "when appending with a DSL block" do
      let(:extended) { described_class.new(sent_message_one, new_message_one) }
      before { allow(sent_message_one).to receive(:thread_from).and_return(extended) }
      subject(:result) { sent_thread.append { text "DSL content" } }

      it "delegates the block to first.thread_from" do
        result
        expect(sent_message_one).to have_received(:thread_from)
      end

      it "returns a SentThread combining all original and new messages" do
        expect(result.sent_messages).to eq([sent_message_one, sent_message_two, sent_message_tre, new_message_one])
      end
    end

    context "when appending with a Message object" do
      let(:client) { instance_double(SlackLine::Client) }
      let(:message) { SlackLine::Message.new("Message content", client:) }
      let(:extended) { described_class.new(sent_message_one, new_message_one) }
      before { allow(sent_message_one).to receive(:thread_from).with(message).and_return(extended) }
      subject(:result) { sent_thread.append(message) }

      it "delegates to first.thread_from with the Message object" do
        result
        expect(sent_message_one).to have_received(:thread_from).with(message)
      end

      it "returns a SentThread combining all original and new messages" do
        expect(result.sent_messages).to eq([sent_message_one, sent_message_two, sent_message_tre, new_message_one])
      end
    end

    context "when appending multiple messages at once" do
      let(:extended) { described_class.new(sent_message_one, new_message_one, new_message_two) }
      before { allow(sent_message_one).to receive(:thread_from).with("First", "Second").and_return(extended) }
      subject(:result) { sent_thread.append("First", "Second") }

      it "returns a SentThread with all original and all new messages" do
        expect(result.sent_messages).to eq([sent_message_one, sent_message_two, sent_message_tre, new_message_one, new_message_two])
      end
    end
  end

  describe "#inspect" do
    subject(:inspect_output) { sent_thread.inspect }

    it "includes class name, channel, size, and thread_ts" do
      expect(inspect_output).to eq('#<SlackLine::SentThread channel="C12345678" size=3 thread_ts="1234567890.123456">')
    end
  end
end
