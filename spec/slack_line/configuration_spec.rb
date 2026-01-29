RSpec.describe SlackLine::Configuration do
  subject(:configuration) { described_class.new(base_config, **overrides) }

  without_env("SLACK_LINE_SLACK_TOKEN",
              "SLACK_LINE_LOOK_UP_USERS",
              "SLACK_LINE_BOT_NAME",
              "SLACK_LINE_DEFAULT_CHANNEL",
              "SLACK_LINE_PER_MESSAGE_DELAY",
              "SLACK_LINE_PER_THREAD_DELAY")

  let(:base_config) { nil }
  let(:overrides) { {} }

  context "when initialized with no arguments" do
    subject(:configuration) { described_class.new }

    it "uses default values" do
      expect(configuration.slack_token).to be_nil
      expect(configuration.look_up_users).to be false
      expect(configuration.bot_name).to be_nil
      expect(configuration.default_channel).to be_nil
      expect(configuration.per_message_delay).to be_within(0.001).of(0.0)
      expect(configuration.per_thread_delay).to be_within(0.001).of(0.0)
    end
  end

  context "when initialized with a base configuration" do
    let(:base_config) do
      described_class.new(
        slack_token: "base_token",
        look_up_users: true,
        bot_name: "BaseBot",
        default_channel: "#base-channel",
        per_message_delay: 1.0,
        per_thread_delay: 2.0
      )
    end

    it "inherits values from the base configuration" do
      expect(configuration.slack_token).to eq("base_token")
      expect(configuration.look_up_users).to be true
      expect(configuration.bot_name).to eq("BaseBot")
      expect(configuration.default_channel).to eq("#base-channel")
      expect(configuration.per_message_delay).to be_within(0.001).of(1.0)
      expect(configuration.per_thread_delay).to be_within(0.001).of(2.0)
    end

    context "AND overrides" do
      let(:overrides) { {bot_name: "OverrideBot", per_thread_delay: 3.0} }

      it "applies overrides over the base configuration" do
        expect(configuration.slack_token).to eq("base_token")
        expect(configuration.look_up_users).to be true
        expect(configuration.bot_name).to eq("OverrideBot")
        expect(configuration.default_channel).to eq("#base-channel")
        expect(configuration.per_message_delay).to be_within(0.001).of(1.0)
        expect(configuration.per_thread_delay).to be_within(0.001).of(3.0)
      end
    end
  end

  context "when initialized with overrides" do
    let(:overrides) do
      {
        slack_token: "override_token",
        look_up_users: true,
        bot_name: "OverrideBot",
        default_channel: "#override-channel",
        per_message_delay: 0.5,
        per_thread_delay: 1.5
      }
    end

    it "uses the override values" do
      expect(configuration.slack_token).to eq("override_token")
      expect(configuration.look_up_users).to be true
      expect(configuration.bot_name).to eq("OverrideBot")
      expect(configuration.default_channel).to eq("#override-channel")
      expect(configuration.per_message_delay).to be_within(0.001).of(0.5)
      expect(configuration.per_thread_delay).to be_within(0.001).of(1.5)
    end
  end

  context "when environment variables are set" do
    with_env(
      "SLACK_LINE_SLACK_TOKEN" => "env_token",
      "SLACK_LINE_LOOK_UP_USERS" => "true",
      "SLACK_LINE_BOT_NAME" => "EnvBot",
      "SLACK_LINE_DEFAULT_CHANNEL" => "#env-channel",
      "SLACK_LINE_PER_MESSAGE_DELAY" => "0.25",
      "SLACK_LINE_PER_THREAD_DELAY" => "0.75"
    )

    it "uses values from environment variables" do
      expect(configuration.slack_token).to eq("env_token")
      expect(configuration.look_up_users).to be true
      expect(configuration.bot_name).to eq("EnvBot")
      expect(configuration.default_channel).to eq("#env-channel")
      expect(configuration.per_message_delay).to be_within(0.001).of(0.25)
      expect(configuration.per_thread_delay).to be_within(0.001).of(0.75)
    end

    context "AND some overrides" do
      let(:overrides) { {slack_token: "override_token", per_message_delay: 0.1} }

      it "applies overrides over environment variables" do
        expect(configuration.slack_token).to eq("override_token")
        expect(configuration.look_up_users).to be true
        expect(configuration.bot_name).to eq("EnvBot")
        expect(configuration.default_channel).to eq("#env-channel")
        expect(configuration.per_message_delay).to be_within(0.001).of(0.1)
        expect(configuration.per_thread_delay).to be_within(0.001).of(0.75)
      end
    end
  end
end
