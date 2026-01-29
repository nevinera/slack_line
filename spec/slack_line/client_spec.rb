RSpec.describe SlackLine::Client do
  subject(:client) { described_class.new(nil, **overrides) }
  let(:overrides) { {slack_token: "fake-slack-token"} }

  context "when no slack_token is provided" do
    let(:overrides) { {} }

    it "raises an ArgumentError" do
      expect { client }.to raise_error(ArgumentError, "slack_token is required")
    end
  end

  describe "#configuration" do
    subject(:configuration) { client.configuration }

    it { is_expected.to be_a(SlackLine::Configuration) }
    it { is_expected.to have_attributes(slack_token: "fake-slack-token") }
  end

  describe "#message" do
    subject(:message) { client.message }

    it { is_expected.to be_nil }
  end

  describe "#thread" do
    subject(:thread) { client.thread }

    it { is_expected.to be_nil }
  end

  describe "#post_message" do
    subject(:post_message) { client.post_message }

    it { is_expected.to be_nil }
  end

  describe "#post_thread" do
    subject(:post_thread) { client.post_thread }

    it { is_expected.to be_nil }
  end
end
