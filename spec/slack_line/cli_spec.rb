RSpec.describe SlackLine::Cli do
  describe "ExitException" do
    it { expect(described_class::ExitException).to be < StandardError }
  end
end
