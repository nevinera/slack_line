RSpec.describe SlackLine::Cli::SlackLineThread do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  let(:slack_client) { instance_double(Slack::Web::Client) }
  let(:first_response) { Slack::Messages::Message.new({ts: "111.000001", channel: "C12345678"}) }
  let(:second_response) { Slack::Messages::Message.new({ts: "111.000002", channel: "C12345678", thread_ts: "111.000001"}) }

  subject(:cli) { described_class.new(argv:, stdout:, stderr:) }

  before { allow(Slack::Web::Client).to receive(:new).and_return(slack_client) }

  describe "with --post-to" do
    let(:argv) { %w[--slack-token fake-token --post-to C12345678 Hello World] }

    before { allow(slack_client).to receive(:chat_postMessage).and_return(first_response, second_response) }

    it "posts the first message without thread_ts" do
      cli.run
      expect(slack_client).to have_received(:chat_postMessage).with(
        channel: "C12345678",
        blocks: [{type: "section", text: {type: "mrkdwn", text: "Hello"}}],
        thread_ts: nil,
        username: nil
      )
    end

    it "posts the second message with the first message's ts as thread_ts" do
      cli.run
      expect(slack_client).to have_received(:chat_postMessage).with(
        channel: "C12345678",
        blocks: [{type: "section", text: {type: "mrkdwn", text: "World"}}],
        thread_ts: "111.000001",
        username: nil
      )
    end

    it "reports to stderr" do
      cli.run
      expect(stderr.string).to include("C12345678")
    end

    context "with --save" do
      let(:argv) { %w[--slack-token fake-token --post-to C12345678 --save /tmp/thread.json Hello World] }

      before { allow(File).to receive(:write) }

      it "saves the posted thread JSON to the given path" do
        cli.run
        expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "thread"'))
      end
    end
  end

  describe "in preview mode" do
    let(:argv) { %w[--slack-token fake-token Hello World] }

    it "writes builder URLs to stderr" do
      cli.run
      expect(stderr.string).to include("block-kit-builder")
    end

    it "writes message JSON to stdout" do
      cli.run
      expect(stdout.string).to include('"type": "section"')
    end
  end

  describe "DSL mode (no content args)" do
    let(:argv) { %w[--slack-token fake-token --post-to C12345678] }

    before do
      allow(Reline).to receive(:readline).and_return('text "Hello"', nil)
      allow(slack_client).to receive(:chat_postMessage).and_return(first_response)
    end

    it "reads content via Reline and posts the assembled thread" do
      cli.run
      expect(slack_client).to have_received(:chat_postMessage).with(
        channel: "C12345678",
        blocks: [{type: "section", text: {type: "mrkdwn", text: "Hello"}}],
        thread_ts: nil,
        username: nil
      )
    end

    it "reports to stderr that it is reading from stdin" do
      cli.run
      expect(stderr.string).to include("reading (as dsl) from stdin")
    end
  end
end
