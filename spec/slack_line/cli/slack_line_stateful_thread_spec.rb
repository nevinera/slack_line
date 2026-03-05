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

      context "when both --state and --message are given" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json --state deploying --message hello] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /Only one of --state or --message/)
        end
      end

      context "when neither --state nor --message is given" do
        let(:argv) { %w[--slack-token fake --path /tmp/thread.json] }

        it "raises ExitException" do
          expect { cli.run }.to raise_error(SlackLine::Cli::ExitException, /One of --state or --message is required/)
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
  end

  describe "subsequent --message append (file exists)" do
    let(:argv) { %w[--slack-token fake --path /tmp/thread.json --message Pipeline\ complete] }

    before do
      allow(File).to receive(:exist?).with("/tmp/thread.json").and_return(true)
      allow(File).to receive(:read).with("/tmp/thread.json").and_return(persisted_message_json)
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

    it "does not update the path file" do
      allow(File).to receive(:write)
      cli.run
      expect(File).not_to have_received(:write)
    end

    it "reports to stderr" do
      cli.run
      expect(stderr.string).to include("C12345678")
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
