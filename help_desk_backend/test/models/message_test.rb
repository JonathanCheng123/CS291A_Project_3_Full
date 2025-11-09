require "test_helper"

class MessageTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      username: "testuser",
      password: "password123",
      password_confirmation: "password123"
    )

    @conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user
    )

    @message = Message.new(
      user: @user,
      conversation: @conversation,
      sender_role: "initiator",
      content: "Hello!"
    )
  end

  test "should be valid with valid attributes" do
    assert @message.valid?
  end

  test "should require content" do
    @message.content = nil
    assert_not @message.valid?
  end

  test "should require sender_role to be either initiator or expert" do
    @message.sender_role = "other"
    assert_not @message.valid?
  end

  test "should belong to a user" do
    @message.user = nil
    assert_not @message.valid?
  end
end
