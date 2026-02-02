RSpec.describe SlackLine::Users do
  let!(:slack_client) { stubbed_instantiation(Slack::Web::Client) }
  subject(:users) { described_class.new(slack_client:) }

  before { allow(slack_client).to receive(:users_list).and_return(response_one, response_two) }
  let(:response_one) do
    Slack::Messages::Message.new({
      ok: true,
      response_metadata: {next_cursor: "cursor123"},
      members: [
        {id: "U01", deleted: false, is_bot: false, profile: {display_name: "Alice"}},
        {id: "U02", deleted: false, is_bot: true, profile: {display_name: "BotUser"}},
        {id: "U03", deleted: true, is_bot: false, profile: {display_name: "DeletedUser"}}
      ]
    })
  end
  let(:response_two) do
    Slack::Messages::Message.new({
      ok: true,
      response_metadata: {next_cursor: nil},
      members: [
        {id: "U04", deleted: false, is_bot: false, profile: {display_name: "Bob"}},
        {id: "U05", deleted: false, is_bot: false, profile: {display_name: "Charlie"}}
      ]
    })
  end

  describe "#users" do
    subject(:all) { users.all }

    it "fetches all non-deleted, non-bot users" do
      expect(all.map(&:id)).to contain_exactly("U01", "U04", "U05")
    end

    it "makes the expected api calls" do
      all
      expect(slack_client).to have_received(:users_list).with({limit: 200}).ordered
      expect(slack_client).to have_received(:users_list).with({limit: 200, cursor: "cursor123"}).ordered
      expect(slack_client).to have_received(:users_list).twice
    end
  end

  describe "#find" do
    it "can find a user by display name" do
      user = users.find(display_name: "Bob")
      expect(user).to have_attributes(id: "U04")
    end

    it "is case insensitive when finding by display name" do
      user = users.find(display_name: "alice")
      expect(user).to have_attributes(id: "U01")
    end

    it "raises UserNotFoundError if the user is not found" do
      expect { users.find(display_name: "NonExistentUser") }.to raise_error(
        SlackLine::UserNotFoundError,
        "User with display name 'NonExistentUser' was not found."
      )
    end
  end
end
