RSpec.describe SlackLine::Cli::SlackLineStatefulThread do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  let(:slack_client) { instance_double(Slack::Web::Client) }
  let(:posted_response) { Slack::Messages::Message.new({ts: "111.000001", channel: "C12345678"}) }
  let(:updated_response) { Slack::Messages::Message.new({ts: "111.000001", channel: "C12345678"}) }
  let(:reply_response) { Slack::Messages::Message.new({ts: "222.000001", channel: "C12345678", thread_ts: "111.000001"}) }

  subject(:cli) { described_class.new(argv:, stdout:, stderr:) }

  before { allow(Slack::Web::Client).to receive(:new).and_return(slack_client) }

  let(:persisted_message_json) do
    JSON.generate(
      type: "message", ts: "111.000001", channel: "C12345678",
      thread_ts: nil, priorly: nil,
      content: [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "[:hammer_and_wrench: Building] Deploy v1.2.3"}}]
    )
  end

  let(:persisted_thread_json) do
    JSON.generate(
      type: "thread",
      messages: [
        {type: "message", ts: "111.000001", channel: "C12345678", thread_ts: nil, priorly: nil,
         content: [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "[:hammer_and_wrench: Building] Deploy v1.2.3"}}]},
        {type: "message", ts: "222.000001", channel: "C12345678", thread_ts: "111.000001", priorly: nil,
         content: [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "First reply"}}]}
      ]
    )
  end

  describe "validation" do
    context "when --path is not given" do
      let(:argv) { %w[--slack-token fake --post-to C12345678 --state building --message hello] }

      it "raises ExitException" do
        expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--path is required/)
      end
    end

    context "for initial post (no file at path)" do
      before { allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(false) }

      context "when --post-to is missing" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json --state building --message hello] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--post-to is required/)
        end
      end

      context "when --state is missing" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json --post-to C12345678 --message hello] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--state is required/)
        end
      end

      context "when --message is missing" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json --post-to C12345678 --state building] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--message is required/)
        end
      end

      context "when --thread is given" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json --post-to C12345678 --state building --message hello --thread] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--thread cannot be used on initial post/)
        end
      end
    end

    context "for subsequent calls (file exists at path)" do
      before do
        allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(true)
        allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_message_json)
      end

      context "when --post-to is given" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json --post-to C99999999 --state deploying] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--post-to cannot be used after initial post/)
        end
      end

      context "when neither --state nor --message is given" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /One of --state or --message is required/)
        end
      end

      context "when --thread is given with --state" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json --thread --state deploying --message hello] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--thread cannot be used with --state/)
        end
      end

      context "when --thread is given without --message" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json --thread] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /--thread requires --message/)
        end
      end
    end
  end

  describe "initial post (no file at path)" do
    let(:argv) do
      %w[--slack-token fake --path /tmp/thread.json --post-to C12345678
        --state :hammer_and_wrench:\ Building --message Deploy\ v1.2.3]
    end

    before do
      allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(false)
      allow(File).to receive(:write)
      allow(slack_client).to receive(:chat_postMessage).and_return(posted_response)
    end

    it "posts a message with the state and message combined" do
      cli.run
      expect(slack_client).to have_received(:chat_postMessage).with(
        channel: "C12345678",
        blocks: [{type: "section", text: {type: "mrkdwn", text: "[:hammer_and_wrench: Building] Deploy v1.2.3"}}],
        thread_ts: nil,
        username: nil
      )
    end

    it "saves the SentMessage JSON to the path" do
      cli.run
      expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "message"'))
    end

    it "reports to stderr" do
      cli.run
      expect(stderr.string).to include("C12345678")
    end
  end

  describe "subsequent --state update (file exists)" do
    let(:argv) { %w[--slack-token fake --path /tmp/thread.json --state :rocket:\ Deploying] }

    before do
      allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(true)
      allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_message_json)
      allow(File).to receive(:write)
      allow(slack_client).to receive(:chat_update).and_return(updated_response)
    end

    it "updates the message with the new state and preserved body" do
      cli.run
      expect(slack_client).to have_received(:chat_update).with(
        channel: "C12345678", ts: "111.000001",
        blocks: [{type: "section", text: {type: "mrkdwn", text: "[:rocket: Deploying] Deploy v1.2.3"}}]
      )
    end

    it "saves the updated SentMessage JSON to the path" do
      cli.run
      expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "message"'))
    end

    it "reports to stderr" do
      cli.run
      expect(stderr.string).to include("C12345678")
    end

    context "when the file contains a SentThread" do
      before { allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_thread_json) }

      it "updates the root message with the new state and preserved body" do
        cli.run
        expect(slack_client).to have_received(:chat_update).with(
          channel: "C12345678", ts: "111.000001",
          blocks: [{type: "section", text: {type: "mrkdwn", text: "[:rocket: Deploying] Deploy v1.2.3"}}]
        )
      end

      it "saves the result as a SentThread" do
        cli.run
        expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "thread"'))
      end
    end
  end

  describe "subsequent --message update (file exists)" do
    let(:argv) { %w[--slack-token fake --path /tmp/thread.json --message Pipeline\ complete] }

    before do
      allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(true)
      allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_message_json)
      allow(File).to receive(:write)
      allow(slack_client).to receive(:chat_update).and_return(updated_response)
    end

    it "updates the initial message with the new body and preserved state" do
      cli.run
      expect(slack_client).to have_received(:chat_update).with(
        channel: "C12345678", ts: "111.000001",
        blocks: [{type: "section", text: {type: "mrkdwn", text: "[:hammer_and_wrench: Building] Pipeline complete"}}]
      )
    end

    it "saves the updated SentMessage JSON to the path" do
      cli.run
      expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "message"'))
    end

    it "reports to stderr" do
      cli.run
      expect(stderr.string).to include("C12345678")
    end

    context "when the file contains a SentThread" do
      before { allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_thread_json) }

      it "updates the root message with the new body and preserved state" do
        cli.run
        expect(slack_client).to have_received(:chat_update).with(
          channel: "C12345678", ts: "111.000001",
          blocks: [{type: "section", text: {type: "mrkdwn", text: "[:hammer_and_wrench: Building] Pipeline complete"}}]
        )
      end

      it "saves the result as a SentThread" do
        cli.run
        expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "thread"'))
      end
    end
  end

  describe "subsequent --state and --message together (file exists)" do
    let(:argv) { %w[--slack-token fake --path /tmp/thread.json --state :rocket:\ Deploying --message Pipeline\ complete] }

    before do
      allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(true)
      allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_message_json)
      allow(File).to receive(:write)
      allow(slack_client).to receive(:chat_update).and_return(updated_response)
    end

    it "updates the initial message with both the new state and new body" do
      cli.run
      expect(slack_client).to have_received(:chat_update).with(
        channel: "C12345678", ts: "111.000001",
        blocks: [{type: "section", text: {type: "mrkdwn", text: "[:rocket: Deploying] Pipeline complete"}}]
      )
    end

    it "saves the updated SentMessage JSON to the path" do
      cli.run
      expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "message"'))
    end

    context "when the file contains a SentThread" do
      before { allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_thread_json) }

      it "updates the root message with both the new state and new body" do
        cli.run
        expect(slack_client).to have_received(:chat_update).with(
          channel: "C12345678", ts: "111.000001",
          blocks: [{type: "section", text: {type: "mrkdwn", text: "[:rocket: Deploying] Pipeline complete"}}]
        )
      end

      it "saves the result as a SentThread" do
        cli.run
        expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "thread"'))
      end
    end
  end

  describe "subsequent --thread --message (file exists)" do
    let(:argv) { %w[--slack-token fake --path /tmp/thread.json --thread --message Pipeline\ complete] }

    before do
      allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(true)
      allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_message_json)
      allow(File).to receive(:write)
      allow(slack_client).to receive(:chat_postMessage).and_return(reply_response)
    end

    it "posts a reply into the thread" do
      cli.run
      expect(slack_client).to have_received(:chat_postMessage).with(
        channel: "C12345678",
        blocks: [{type: "section", text: {type: "mrkdwn", text: "Pipeline complete"}}],
        thread_ts: "111.000001",
        username: nil
      )
    end

    it "saves the resulting SentThread JSON to the path" do
      cli.run
      expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "thread"'))
    end

    it "reports to stderr" do
      cli.run
      expect(stderr.string).to include("C12345678")
    end

    context "when the file already contains a SentThread" do
      let(:persisted_thread_json) do
        JSON.generate(
          type: "thread",
          messages: [
            {type: "message", ts: "111.000001", channel: "C12345678", thread_ts: nil,
             content: [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "[:building:] Start"}}], priorly: nil},
            {type: "message", ts: "111.000002", channel: "C12345678", thread_ts: "111.000001",
             content: [{"type" => "section", "text" => {"type" => "mrkdwn", "text" => "First reply"}}], priorly: nil}
          ]
        )
      end

      before { allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_thread_json) }

      it "appends to the existing thread" do
        cli.run
        expect(slack_client).to have_received(:chat_postMessage).with(
          channel: "C12345678",
          blocks: anything,
          thread_ts: "111.000001",
          username: nil
        )
      end

      it "saves the updated SentThread JSON to the path" do
        cli.run
        expect(File).to have_received(:write).with("/tmp/thread.json", include('"type": "thread"'))
      end
    end
  end

  describe "when DiskCaching::NoLightly is raised" do
    let(:argv) { %w[--slack-token fake --path /tmp/thread.json --post-to C12345678 --state s --message m] }

    before do
      allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(false)
      allow(cli).to receive(:run_initial).and_raise(SlackLine::DiskCaching::NoLightly, "lightly gem required")
    end

    it "raises ExitException" do
      expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, "lightly gem required")
    end
  end

  describe "when Configuration::InvalidValue is raised" do
    let(:argv) { %w[--slack-token fake --path /tmp/thread.json --post-to C12345678 --state s --message m] }

    before do
      allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(false)
      allow(cli).to receive(:run_initial).and_raise(SlackLine::Configuration::InvalidValue, "invalid duration")
    end

    it "raises ExitException" do
      expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, "invalid duration")
    end
  end
end
