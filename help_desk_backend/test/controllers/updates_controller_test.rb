require "test_helper"

class UpdatesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(username: "testuser", password: "password123")
    @expert_user = User.create!(username: "expertuser", password: "password123")
    @expert_profile = ExpertProfile.create!(user: @expert_user)
  end

  # Tests for GET /api/conversations/updates
  test "GET /api/conversations/updates returns user's conversations" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user,
      status: "waiting"
    )
    
    get "/api/conversations/updates", params: { userId: @user.id }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal conversation.id.to_s, response_data.first["id"]
  end

  test "GET /api/conversations/updates requires userId parameter" do
    get "/api/conversations/updates"
    assert_response :bad_request
  end

  test "GET /api/conversations/updates filters by since parameter" do
    old_conversation = Conversation.create!(
      title: "Old Conversation",
      initiator: @user,
      status: "waiting",
      updated_at: 2.hours.ago
    )
    new_conversation = Conversation.create!(
      title: "New Conversation",
      initiator: @user,
      status: "waiting",
      updated_at: 30.minutes.ago
    )
    
    since_time = 1.hour.ago.iso8601
    get "/api/conversations/updates", params: { userId: @user.id, since: since_time }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal new_conversation.id.to_s, response_data.first["id"]
  end

  # Tests for GET /api/messages/updates
  test "GET /api/messages/updates returns user's messages" do
    conversation = Conversation.create!(
      title: "Test",
      initiator: @user,
      status: "waiting"
    )
    message = Message.create!(
      conversation: conversation,
      user: @user,
      sender_role: "initiator",
      content: "Test message"
    )
    
    get "/api/messages/updates", params: { userId: @user.id }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal message.id.to_s, response_data.first["id"]
  end

  test "GET /api/messages/updates requires userId parameter" do
    get "/api/messages/updates"
    assert_response :bad_request
  end

  test "GET /api/messages/updates filters by since parameter" do
    conversation = Conversation.create!(
      title: "Test",
      initiator: @user,
      status: "waiting"
    )
    old_message = Message.create!(
      conversation: conversation,
      user: @user,
      sender_role: "initiator",
      content: "Old message",
      created_at: 2.hours.ago
    )
    new_message = Message.create!(
      conversation: conversation,
      user: @user,
      sender_role: "initiator",
      content: "New message",
      created_at: 30.minutes.ago
    )
    
    since_time = 1.hour.ago.iso8601
    get "/api/messages/updates", params: { userId: @user.id, since: since_time }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal new_message.id.to_s, response_data.first["id"]
  end

  # Test for GET /api/expert-queue/updates
  test "GET /api/expert-queue/updates requires expertId parameter" do
    get "/api/expert-queue/updates"
    assert_response :bad_request
  end

end