RSpec.describe SlackLine::Groups do
  let!(:slack_client) { stubbed_instantiation(Slack::Web::Client) }
  subject(:groups) { described_class.new(slack_client:) }

  before { allow(slack_client).to receive(:usergroups_list).and_return(response) }
  let(:response) do
    Slack::Messages::Message.new({
      ok: true,
      usergroups: [
        {id: "S01", handle: "engineering", name: "Engineering"},
        {id: "S02", handle: "design", name: "Design"},
        {id: "S03", handle: "ops", name: "Operations"}
      ]
    })
  end

  describe "#all" do
    subject(:all) { groups.all }

    it "returns all usergroups" do
      expect(all.map(&:id)).to contain_exactly("S01", "S02", "S03")
    end

    it "makes the expected api call" do
      all
      expect(slack_client).to have_received(:usergroups_list).once
    end
  end

  describe "#find" do
    it "can find a group by handle" do
      group = groups.find(handle: "engineering")
      expect(group).to have_attributes(id: "S01")
    end

    it "is case insensitive when finding by handle" do
      group = groups.find(handle: "Design")
      expect(group).to have_attributes(id: "S02")
    end

    it "returns nil if the group is not found" do
      expect(groups.find(handle: "nonexistent")).to be_nil
    end
  end
end
