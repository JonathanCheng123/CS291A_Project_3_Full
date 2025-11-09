require "test_helper"

class MessagesTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(username: "testuser", password: "password123")
    @expert_user = User.create!(username: "expertuser", password: "password123")
    @token = JwtService.encode(@user)
    @expert_token = JwtService.encode(@expert_user)
    @conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user,
      assigned_expert: @expert_user,
      status: "active"
    )
  end

  test "GET /conversations/:conversation_id/messages returns messages" do
    message = Message.create!(
      conversation: @conversation,
      user: @user,
      sender_role: "initiator",
      content: "Test message"
    )
    get "/conversations/#{@conversation.id}/messages",
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data.length
    assert_equal message.content, response_data.first["content"]
  end

  test "GET /conversations/:conversation_id/messages returns messages in chronological order" do
    message1 = Message.create!(
      conversation: @conversation,
      user: @user,
      sender_role: "initiator",
      content: "First message",
      created_at: 2.hours.ago
    )
    message2 = Message.create!(
      conversation: @conversation,
      user: @expert_user,
      sender_role: "expert",
      content: "Second message",
      created_at: 1.hour.ago
    )
    get "/conversations/#{@conversation.id}/messages",
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 2, response_data.length
    assert_equal "First message", response_data.first["content"]
    assert_equal "Second message", response_data.last["content"]
  end

  test "GET /conversations/:conversation_id/messages requires authentication" do
    get "/conversations/#{@conversation.id}/messages"
    assert_response :unauthorized
  end

  test "GET /conversations/:conversation_id/messages returns 404 for non-existent conversation" do
    get "/conversations/99999/messages",
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :not_found
  end

  test "POST /messages creates a new message as initiator" do
    post "/messages",
         params: { conversationId: @conversation.id, content: "New message" },
         headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "New message", response_data["content"]
    assert_equal @user.id.to_s, response_data["senderId"]
    assert_equal "initiator", response_data["senderRole"]
  end

  test "POST /messages creates a new message as expert" do
    post "/messages",
         params: { conversationId: @conversation.id, content: "Expert reply" },
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "Expert reply", response_data["content"]
    assert_equal @expert_user.id.to_s, response_data["senderId"]
    assert_equal "expert", response_data["senderRole"]
  end

  test "POST /messages requires authentication" do
    post "/messages",
         params: { conversationId: @conversation.id, content: "Test" }
    assert_response :unauthorized
  end

  test "POST /messages requires content" do
    post "/messages",
         params: { conversationId: @conversation.id },
         headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :unprocessable_entity
  end

  test "POST /messages requires user to be participant in conversation" do
    other_user = User.create!(username: "otheruser", password: "password123")
    other_token = JwtService.encode(other_user)
    post "/messages",
         params: { conversationId: @conversation.id, content: "Unauthorized message" },
         headers: { "Authorization" => "Bearer #{other_token}" }
    assert_response :forbidden
  end

  test "POST /messages response includes senderUsername" do
    post "/messages",
         params: { conversationId: @conversation.id, content: "Test message" },
         headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal @user.username, response_data["senderUsername"]
  end

  test "PUT /messages/:id/read requires authentication" do
    message = Message.create!(
      conversation: @conversation,
      user: @expert_user,
      sender_role: "expert",
      content: "Test message"
    )
    put "/messages/#{message.id}/read"
    assert_response :unauthorized
  end

  test "GET /conversations/:conversation_id/messages includes isRead status" do
    Message.create!(
      conversation: @conversation,
      user: @user,
      sender_role: "initiator",
      content: "Unread message",
      is_read: false
    )
    Message.create!(
      conversation: @conversation,
      user: @expert_user,
      sender_role: "expert",
      content: "Read message",
      is_read: true
    )
    get "/conversations/#{@conversation.id}/messages",
        headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal false, response_data.first["isRead"]
    assert_equal true, response_data.last["isRead"]
  end

  test "POST /messages response includes all message fields" do
    post "/messages",
         params: { conversationId: @conversation.id, content: "Complete test" },
         headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :created
    response_data = JSON.parse(response.body)
    assert response_data.key?("id")
    assert response_data.key?("conversationId")
    assert response_data.key?("senderId")
    assert response_data.key?("senderUsername")
    assert response_data.key?("senderRole")
    assert response_data.key?("content")
    assert response_data.key?("timestamp")
    assert response_data.key?("isRead")
  end
end