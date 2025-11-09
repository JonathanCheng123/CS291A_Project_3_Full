require "test_helper"

class ExpertAssignmentTest < ActiveSupport::TestCase
  def setup
    @initiator = User.create!(username: "alice", password: "password123")
    @expert = User.create!(username: "bob", password: "password123")
    @conversation = Conversation.create!(title: "Support Chat", initiator: @initiator)
    @assignment = ExpertAssignment.new(conversation: @conversation, expert: @expert)
  end

  test "is valid with valid attributes" do
    assert @assignment.valid?
  end

  test "is invalid without a conversation" do
    @assignment.conversation = nil
    assert_not @assignment.valid?
    assert_includes @assignment.errors[:conversation], "must exist"
  end
end
