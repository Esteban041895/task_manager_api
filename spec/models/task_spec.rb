require "rails_helper"

RSpec.describe Task, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:task)).to be_valid
    end

    it "requires title" do
      expect(build(:task, title: "")).not_to be_valid
    end

    it "defaults status to pending" do
      task = Task.create!(user: create(:user), title: "Default status task")
      expect(task.status).to eq("pending")
    end

    it "raises ArgumentError for an unknown status value" do
      expect { build(:task, status: "flying") }.to raise_error(ArgumentError)
    end

    it "requires a user" do
      expect(build(:task, user: nil)).not_to be_valid
    end
  end

  describe "enum" do
    it "exposes pending, in_progress, completed" do
      expect(Task.statuses.keys).to contain_exactly("pending", "in_progress", "completed")
    end
  end

  describe ".for_user" do
    it "returns only tasks belonging to the given user" do
      user  = create(:user)
      other = create(:user)
      own   = create(:task, user: user)
      create(:task, user: other)

      expect(Task.for_user(user)).to contain_exactly(own)
    end
  end
end
