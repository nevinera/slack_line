RSpec.describe SlackLine::MessageSender do
  subject(:message_sender) { described_class.new(message:, client:, to:, thread_ts:) }

  let(:content) { Slack::BlockKit.blocks { |b| b.section { |s| s.mrkdwn(text: "Hello") } } }
  let(:message) { instance_double(SlackLine::Message, content:) }

  let(:response) { Slack::Messages::Message.new({ok: true, ts: "1234567890.123456", channel: "A1792321"}) }
  let(:slack_client) { instance_double(Slack::Web::Client, chat_postMessage: response) }
  let(:configuration) { instance_double(SlackLine::Configuration, default_channel: "#default", bot_name: "MyBot", backoff: true) }
  let(:users) { instance_double(SlackLine::Users) }
  let(:client) { instance_double(SlackLine::Client, configuration:, slack_client:, users:) }

  let(:to) { nil }
  let(:thread_ts) { nil }

  before { allow(slack_client).to receive(:chat_postMessage).and_return(response) }

  describe "#post" do
    subject(:sent_message) { message_sender.post }

    context "with no explicit 'to' parameter" do
      let(:to) { nil }

      it "sends the message to the correct channel" do
        sent_message
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "#default", blocks: content.as_json, thread_ts: nil, username: "MyBot")
      end
    end

    context "with an explicit 'to' parameter" do
      let(:to) { "#custom-channel" }

      it "sends the message to the correct channel" do
        sent_message
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "#custom-channel", blocks: content.as_json, thread_ts: nil, username: "MyBot")
      end
    end

    it "returns a SentMessage with the correct attributes" do
      expect(sent_message).to be_a(SlackLine::SentMessage)
      expect(sent_message.content).to eq(content.as_json)
      expect(sent_message.response).to eq(response)
    end

    context "when 'to' is a username" do
      let(:to) { "@alice" }
      let(:alice) { Hashie::Mash.new(id: "U12345", profile: {display_name: "alice"}) }
      let(:users) { instance_double(SlackLine::Users, find: alice) }

      it "resolves the username to a user ID and sends the message" do
        sent_message
        expect(users).to have_received(:find).with(display_name: "alice")
        expect(slack_client).to have_received(:chat_postMessage)
          .with(channel: "U12345", blocks: content.as_json, thread_ts: nil, username: "MyBot")
      end

      context "when the user is not found" do
        let(:users) { instance_double(SlackLine::Users, find: nil) }

        it "raises UserNotFoundError" do
          expect { sent_message }.to raise_error(
            SlackLine::UserNotFoundError,
            "User with display name 'alice' was not found."
          )
        end
      end
    end

    context "when Slack rate-limits the request" do
      let(:rate_limit_error) do
        Class.new(Slack::Web::Api::Errors::TooManyRequestsError) do
          def initialize = nil
          def retry_after = 0
        end.new
      end

      context "and backoff is enabled" do
        before { allow(configuration).to receive(:backoff).and_return(true) }

        context "and the retry succeeds" do
          before do
            call_count = 0
            allow(slack_client).to receive(:chat_postMessage) do
              call_count += 1
              raise rate_limit_error if call_count == 1
              response
            end
          end

          it "retries and returns a SentMessage" do
            expect(sent_message).to be_a(SlackLine::SentMessage)
            expect(slack_client).to have_received(:chat_postMessage).twice
          end
        end

        context "and the request is rate-limited more than twice" do
          before { allow(slack_client).to receive(:chat_postMessage).and_raise(rate_limit_error) }

          it "raises the error after 2 retries" do
            expect { sent_message }.to raise_error(Slack::Web::Api::Errors::TooManyRequestsError)
            expect(slack_client).to have_received(:chat_postMessage).exactly(3).times
          end
        end
      end

      context "and backoff is disabled" do
        before do
          allow(configuration).to receive(:backoff).and_return(false)
          allow(slack_client).to receive(:chat_postMessage).and_raise(rate_limit_error)
        end

        it "raises the error immediately without retrying" do
          expect { sent_message }.to raise_error(Slack::Web::Api::Errors::TooManyRequestsError)
          expect(slack_client).to have_received(:chat_postMessage).once
        end
      end
    end
  end
end
