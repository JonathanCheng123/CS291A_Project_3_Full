require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  def setup
    @initiator = User.create!(username: "alice", password: "password123")
    @expert = User.create!(username: "bob", password: "password123")
    @conversation = Conversation.create!(title: "Test Conversation", initiator: @initiator, assigned_expert: @expert)
  end

  test "is valid with valid attributes" do
    assert @conversation.valid?
  end

  test "is invalid without a title" do
    convo = Conversation.new(initiator: @initiator)
    assert_not convo.valid?
    assert_includes convo.errors[:title], "can't be blank"
  end

  test "belongs to an initiator" do
    assert_equal @initiator, @conversation.initiator
  end

  test "can have an assigned expert" do
    assert_equal @expert, @conversation.assigned_expert
  end

  test "assigned expert is optional" do
    convo = Conversation.new(title: "No expert yet", initiator: @initiator)
    assert convo.valid?
  end
end
