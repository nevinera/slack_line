RSpec.describe SlackLine::Cli::SlackLineMessage do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  let(:slack_client) { instance_double(Slack::Web::Client) }
  let(:posted_response) { Slack::Messages::Message.new({ts: "111.000001", channel: "C12345678"}) }
  let(:updated_response) { Slack::Messages::Message.new({ts: "111.000002", channel: "C12345678"}) }

  subject(:cli) { described_class.new(argv:, stdout:, stderr:) }

  before { allow(Slack::Web::Client).to receive(:new).and_return(slack_client) }

  # JSON fixtures representing previously-persisted objects
  let(:persisted_message_json) do
    JSON.generate(type: "message", ts: "111.000001", channel: "C12345678",
      thread_ts: nil, content: [], priorly: nil)
  end

  let(:persisted_thread_json) do
    JSON.generate(
      type: "thread",
      messages: [
        {type: "message", ts: "111.000001", channel: "C12345678", thread_ts: nil,
         content: [{type: "section", text: {type: "mrkdwn", text: "First"}}], priorly: nil},
        {type: "message", ts: "111.000002", channel: "C12345678", thread_ts: "111.000001",
         content: [{type: "section", text: {type: "mrkdwn", text: "Second"}}], priorly: nil}
      ]
    )
  end

  describe "validation" do
    context "when --append and --update are both given" do
      let(:argv) { %w[--slack-token fake --append /tmp/msg.json --update /tmp/msg.json content] }

      it "raises ExitException" do
        expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /Only one of --post-to, --append, or --update/)
      end
    end

    context "when --message-number is given without --update" do
      let(:argv) { %w[--slack-token fake --message-number 1 --post-to C12345678 content] }

      it "raises ExitException" do
        expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--message-number requires --update/)
      end
    end
  end

  describe "with --post-to" do
    let(:argv) { %w[--slack-token fake-token --post-to C12345678 Hello world] }

    before { allow(slack_client).to receive(:chat_postMessage).and_return(posted_response) }

    it "posts the message blocks to the given channel" do
      cli.run
      expect(slack_client).to have_received(:chat_postMessage).with(
        channel: "C12345678",
        blocks: [
          {type: "section", text: {type: "mrkdwn", text: "Hello"}},
          {type: "section", text: {type: "mrkdwn", text: "world"}}
        ],
        thread_ts: nil,
        username: nil
      )
    end

    it "reports to stderr" do
      cli.run
      expect(stderr.string).to include("C12345678")
    end

    context "with --save" do
      let(:argv) { %w[--slack-token fake-token --post-to C12345678 --save /tmp/msg.json Hello] }

      before { allow(File).to receive(:write) }

      it "saves the posted message JSON to the given path" do
        cli.run
        expect(File).to have_received(:write).with("/tmp/msg.json", include('"type": "message"'))
      end
    end
  end

  describe "in preview mode" do
    let(:argv) { %w[--slack-token fake-token Hello] }

    it "writes the preview URL to stderr" do
      cli.run
      expect(stderr.string).to include("block-kit-builder")
    end

    it "writes JSON blocks to stdout" do
      cli.run
      expect(stdout.string).to include('"type": "section"')
    end
  end

  describe "with --append" do
    let(:reply_response) { Slack::Messages::Message.new({ts: "222.000001", channel: "C12345678", thread_ts: "111.000001"}) }

    before { allow(slack_client).to receive(:chat_postMessage).and_return(reply_response) }

    context "when the file contains a persisted SentMessage" do
      let(:argv) { %w[--slack-token fake-token --append /tmp/msg.json Reply] }

      before { allow(File).to receive(:read).with("/tmp/msg.json").and_return(persisted_message_json) }

      it "posts the reply into the message's thread" do
        cli.run
        expect(slack_client).to have_received(:chat_postMessage).with(
          channel: "C12345678", blocks: anything, thread_ts: "111.000001", username: nil
        )
      end

      it "reports to stderr" do
        cli.run
        expect(stderr.string).to include("C12345678")
      end
    end

    context "when the file contains a persisted SentThread" do
      let(:argv) { %w[--slack-token fake-token --append /tmp/thread.json Reply] }

      before { allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_thread_json) }

      it "posts the reply into the thread" do
        cli.run
        expect(slack_client).to have_received(:chat_postMessage).with(
          channel: "C12345678", blocks: anything, thread_ts: "111.000001", username: nil
        )
      end
    end

    context "with --save" do
      let(:argv) { %w[--slack-token fake-token --append /tmp/msg.json --save /tmp/result.json Reply] }

      before do
        allow(File).to receive(:read).with("/tmp/msg.json").and_return(persisted_message_json)
        allow(File).to receive(:write)
      end

      it "saves the resulting thread JSON to the given path" do
        cli.run
        expect(File).to have_received(:write).with("/tmp/result.json", include('"type": "thread"'))
      end
    end
  end

  describe "with --update" do
    before { allow(slack_client).to receive(:chat_update).and_return(updated_response) }

    context "when the file contains a persisted SentMessage" do
      let(:argv) { %w[--slack-token fake-token --update /tmp/msg.json Updated] }

      before { allow(File).to receive(:read).with("/tmp/msg.json").and_return(persisted_message_json) }

      it "updates the message with the new content" do
        cli.run
        expect(slack_client).to have_received(:chat_update).with(
          channel: "C12345678", ts: "111.000001", blocks: anything
        )
      end

      it "reports to stderr" do
        cli.run
        expect(stderr.string).to include("C12345678")
      end

      context "when --message-number is also given" do
        let(:argv) { %w[--slack-token fake-token --update /tmp/msg.json --message-number 0 Updated] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--message-number cannot be used when updating a single message/)
        end
      end

      context "with --save" do
        let(:argv) { %w[--slack-token fake-token --update /tmp/msg.json --save /tmp/updated.json Updated] }

        before { allow(File).to receive(:write) }

        it "saves the updated message JSON to the given path" do
          cli.run
          expect(File).to have_received(:write).with("/tmp/updated.json", include('"type": "message"'))
        end
      end
    end

    context "when the file contains a persisted SentThread" do
      before { allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_thread_json) }

      context "when --message-number is not given" do
        let(:argv) { %w[--slack-token fake-token --update /tmp/thread.json Updated] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--message-number is required when updating a thread/)
        end
      end

      context "when --message-number is out of range" do
        let(:argv) { %w[--slack-token fake-token --update /tmp/thread.json --message-number 2 Updated] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--message-number 2 is out of range \(thread has 2 messages\)/)
        end
      end

      context "when --message-number is valid" do
        let(:argv) { %w[--slack-token fake-token --update /tmp/thread.json --message-number 1 Updated] }

        it "updates the specified message" do
          cli.run
          expect(slack_client).to have_received(:chat_update).with(
            channel: "C12345678", ts: "111.000002", blocks: anything
          )
        end

        it "reports to stderr" do
          cli.run
          expect(stderr.string).to include("C12345678")
        end

        context "with --save" do
          let(:argv) { %w[--slack-token fake-token --update /tmp/thread.json --message-number 1 --save /tmp/updated.json Updated] }

          before { allow(File).to receive(:write) }

          it "saves the updated thread JSON to the given path" do
            cli.run
            expect(File).to have_received(:write).with("/tmp/updated.json", include('"type": "thread"'))
          end
        end
      end
    end
  end

  describe "with --no-backoff" do
    let(:argv) { %w[--slack-token fake-token --no-backoff Hello] }

    without_env("SLACK_LINE_NO_BACKOFF")

    it "disables backoff in configuration" do
      expect(cli.configuration.backoff).to be false
    end
  end

  describe "DSL mode (no content args)" do
    context "with --update" do
      let(:argv) { %w[--slack-token fake-token --update /tmp/msg.json] }

      before do
        allow(Reline).to receive(:readline).and_return('text "Updated via DSL"', nil)
        allow(File).to receive(:read).with("/tmp/msg.json").and_return(persisted_message_json)
        allow(slack_client).to receive(:chat_update).and_return(updated_response)
      end

      it "reads content via Reline and updates the message" do
        cli.run
        expect(slack_client).to have_received(:chat_update).with(
          channel: "C12345678", ts: "111.000001",
          blocks: [{type: "section", text: {type: "mrkdwn", text: "Updated via DSL"}}]
        )
      end
    end

    let(:argv) { %w[--slack-token fake-token --post-to C12345678] }

    before do
      allow(Reline).to receive(:readline).and_return('text "Hello"', nil)
      allow(slack_client).to receive(:chat_postMessage).and_return(posted_response)
    end

    it "reads content via Reline and posts the assembled message" do
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
