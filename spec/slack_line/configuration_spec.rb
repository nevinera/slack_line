RSpec.describe SlackLine::Configuration do
  subject(:configuration) { described_class.new(base_config, **overrides) }

  let(:base_config) { nil }
  let(:overrides) { {} }

  context "when initialized with no arguments" do
    subject(:configuration) { described_class.new }

    it "uses default values" do
      expect(configuration.slack_token).to be_nil
      expect(configuration.look_up_users).to be false
      expect(configuration.bot_name).to be_nil
      expect(configuration.default_channel).to be_nil
      expect(configuration.allow_dsl).to be true
    end
  end

  context "when initialized with a base configuration" do
    let(:base_config) do
      described_class.new(
        slack_token: "base_token",
        look_up_users: true,
        bot_name: "BaseBot",
        default_channel: "#base-channel",
        allow_dsl: false
      )
    end

    it "inherits values from the base configuration" do
      expect(configuration.slack_token).to eq("base_token")
      expect(configuration.look_up_users).to be true
      expect(configuration.bot_name).to eq("BaseBot")
      expect(configuration.default_channel).to eq("#base-channel")
      expect(configuration.allow_dsl).to be false
    end

    context "AND overrides" do
      let(:overrides) { {bot_name: "OverrideBot", allow_dsl: true} }

      it "applies overrides over the base configuration" do
        expect(configuration.slack_token).to eq("base_token")
        expect(configuration.look_up_users).to be true
        expect(configuration.bot_name).to eq("OverrideBot")
        expect(configuration.default_channel).to eq("#base-channel")
        expect(configuration.allow_dsl).to be true
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
        allow_dsl: false
      }
    end

    it "uses the override values" do
      expect(configuration.slack_token).to eq("override_token")
      expect(configuration.look_up_users).to be true
      expect(configuration.bot_name).to eq("OverrideBot")
      expect(configuration.default_channel).to eq("#override-channel")
      expect(configuration.allow_dsl).to be false
    end
  end

  context "when environment variables are set" do
    def mock_envar(name, value)
      allow(ENV).to receive(:key?).with(name).and_return(true)
      allow(ENV).to receive(:fetch).with(name).and_return(value)
    end

    before do
      allow(ENV).to receive(:key?).and_call_original
      allow(ENV).to receive(:fetch).and_call_original
      mock_envar("SLACK_LINE_SLACK_TOKEN", "env_token")
      mock_envar("SLACK_LINE_LOOK_UP_USERS", "true")
      mock_envar("SLACK_LINE_BOT_NAME", "EnvBot")
      mock_envar("SLACK_LINE_DEFAULT_CHANNEL", "#env-channel")
      mock_envar("SLACK_LINE_ALLOW_DSL", "false")
    end

    it "uses values from environment variables" do
      expect(configuration.slack_token).to eq("env_token")
      expect(configuration.look_up_users).to be true
      expect(configuration.bot_name).to eq("EnvBot")
      expect(configuration.default_channel).to eq("#env-channel")
      expect(configuration.allow_dsl).to be false
    end

    context "AND some overrides" do
      let(:overrides) { {slack_token: "override_token", allow_dsl: true} }

      it "applies overrides over environment variables" do
        expect(configuration.slack_token).to eq("override_token")
        expect(configuration.look_up_users).to be true
        expect(configuration.bot_name).to eq("EnvBot")
        expect(configuration.default_channel).to eq("#env-channel")
        expect(configuration.allow_dsl).to be true
      end
    end
  end
end
