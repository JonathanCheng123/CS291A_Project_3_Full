require "test_helper"

class ExpertTest < ActionDispatch::IntegrationTest
  def setup
    @expert_user = User.create!(username: "expertuser", password: "password123")
    @expert_profile = ExpertProfile.create!(user: @expert_user, bio: "Expert in Rails", knowledge_base_links: ["https://example.com"])
    @expert_token = JwtService.encode(@expert_user)
    
    @questioner = User.create!(username: "questioner", password: "password123")
    @questioner_token = JwtService.encode(@questioner)
  end

  test "GET /expert/queue returns waiting and assigned conversations" do
    waiting_conv = Conversation.create!(
      title: "Waiting Conversation",
      initiator: @questioner,
      status: "waiting"
    )
    assigned_conv = Conversation.create!(
      title: "Assigned Conversation",
      initiator: @questioner,
      assigned_expert: @expert_user,
      status: "active"
    )
    
    get "/expert/queue", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data["waitingConversations"].length
    assert_equal 1, response_data["assignedConversations"].length
    assert_equal waiting_conv.id.to_s, response_data["waitingConversations"].first["id"]
    assert_equal assigned_conv.id.to_s, response_data["assignedConversations"].first["id"]
  end

  test "GET /expert/queue requires authentication" do
    get "/expert/queue"
    assert_response :unauthorized
  end

  test "GET /expert/queue requires expert profile" do
    user_without_profile = User.create!(username: "noexpert", password: "password123")
    ExpertProfile.where(user: user_without_profile).destroy_all
    token = JwtService.encode(user_without_profile)
    
    get "/expert/queue", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :forbidden
  end

  test "GET /expert/queue orders waiting conversations by created_at ascending" do
    conv1 = Conversation.create!(
      title: "First",
      initiator: @questioner,
      status: "waiting",
      created_at: 2.hours.ago
    )
    conv2 = Conversation.create!(
      title: "Second",
      initiator: @questioner,
      status: "waiting",
      created_at: 1.hour.ago
    )
    
    get "/expert/queue", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    waiting = response_data["waitingConversations"]
    assert_equal conv1.id.to_s, waiting.first["id"]
    assert_equal conv2.id.to_s, waiting.last["id"]
  end

  test "GET /expert/queue orders assigned conversations by updated_at descending" do
    conv1 = Conversation.create!(
      title: "First Assigned",
      initiator: @questioner,
      assigned_expert: @expert_user,
      status: "active",
      updated_at: 2.hours.ago
    )
    conv2 = Conversation.create!(
      title: "Second Assigned",
      initiator: @questioner,
      assigned_expert: @expert_user,
      status: "active",
      updated_at: 1.hour.ago
    )
    
    get "/expert/queue", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assigned = response_data["assignedConversations"]
    assert_equal conv2.id.to_s, assigned.first["id"]
    assert_equal conv1.id.to_s, assigned.last["id"]
  end

  test "POST /expert/conversations/:conversation_id/claim assigns conversation to expert" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @questioner,
      status: "waiting"
    )
    
    post "/expert/conversations/#{conversation.id}/claim",
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    
    conversation.reload
    assert_equal @expert_user.id, conversation.assigned_expert_id
    assert_equal "active", conversation.status
  end

  test "POST /expert/conversations/:conversation_id/claim creates expert assignment" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @questioner,
      status: "waiting"
    )
    
    assert_difference("ExpertAssignment.count", 1) do
      post "/expert/conversations/#{conversation.id}/claim",
           headers: { "Authorization" => "Bearer #{@expert_token}" }
    end
    
    assignment = ExpertAssignment.last
    assert_equal conversation.id, assignment.conversation_id
    assert_equal @expert_user.id, assignment.expert_id
    assert_equal "active", assignment.status
    assert_not_nil assignment.assigned_at
  end

  test "POST /expert/conversations/:conversation_id/claim requires authentication" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @questioner,
      status: "waiting"
    )
    
    post "/expert/conversations/#{conversation.id}/claim"
    assert_response :unauthorized
  end

  test "POST /expert/conversations/:conversation_id/claim fails if already assigned" do
    other_expert = User.create!(username: "otherexpert", password: "password123")
    ExpertProfile.create!(user: other_expert)
    conversation = Conversation.create!(
      title: "Assigned Conversation",
      initiator: @questioner,
      assigned_expert: other_expert,
      status: "active"
    )
    
    post "/expert/conversations/#{conversation.id}/claim",
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_includes response_data["error"], "already assigned"
  end

  test "POST /expert/conversations/:conversation_id/unclaim unassigns expert from conversation" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @questioner,
      assigned_expert: @expert_user,
      status: "active"
    )
    assignment = ExpertAssignment.create!(
      conversation: conversation,
      expert: @expert_user,
      status: "active",
      assigned_at: Time.current
    )
    
    post "/expert/conversations/#{conversation.id}/unclaim",
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    
    conversation.reload
    assert_nil conversation.assigned_expert_id
    assert_equal "waiting", conversation.status
    
    assignment.reload
    assert_equal "unassigned", assignment.status
  end

  test "POST /expert/conversations/:conversation_id/unclaim requires authentication" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @questioner,
      assigned_expert: @expert_user,
      status: "active"
    )
    
    post "/expert/conversations/#{conversation.id}/unclaim"
    assert_response :unauthorized
  end

  test "POST /expert/conversations/:conversation_id/unclaim fails if not assigned to expert" do
    other_expert = User.create!(username: "otherexpert", password: "password123")
    ExpertProfile.create!(user: other_expert)
    conversation = Conversation.create!(
      title: "Other Expert Conversation",
      initiator: @questioner,
      assigned_expert: other_expert,
      status: "active"
    )
    
    post "/expert/conversations/#{conversation.id}/unclaim",
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :forbidden
  end

  test "GET /expert/profile returns expert profile" do
    get "/expert/profile", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal @expert_profile.id.to_s, response_data["id"]
    assert_equal @expert_user.id.to_s, response_data["userId"]
    assert_equal "Expert in Rails", response_data["bio"]
    assert_equal ["https://example.com"], response_data["knowledgeBaseLinks"]
  end

  test "GET /expert/profile requires authentication" do
    get "/expert/profile"
    assert_response :unauthorized
  end

  test "GET /expert/profile requires expert profile" do
    user_without_profile = User.create!(username: "noexpert", password: "password123")
    ExpertProfile.where(user: user_without_profile).destroy_all
    token = JwtService.encode(user_without_profile)
    
    get "/expert/profile", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :forbidden
  end

  test "PUT /expert/profile updates bio" do
    put "/expert/profile",
        params: { bio: "Updated bio" },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    
    @expert_profile.reload
    assert_equal "Updated bio", @expert_profile.bio
  end

  test "PATCH /expert/profile updates knowledge_base_links" do
    patch "/expert/profile",
          params: { knowledgeBaseLinks: ["https://new.com", "https://link.com"] },
          headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    
    @expert_profile.reload
    assert_equal ["https://new.com", "https://link.com"], @expert_profile.knowledge_base_links
  end

  test "PUT /expert/profile requires authentication" do
    put "/expert/profile", params: { bio: "Test" }
    assert_response :unauthorized
  end

  test "PUT /expert/profile returns updated profile" do
    put "/expert/profile",
        params: { bio: "New bio", knowledgeBaseLinks: ["https://updated.com"] },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal "New bio", response_data["bio"]
    assert_equal ["https://updated.com"], response_data["knowledgeBaseLinks"]
  end

  test "GET /expert/assignments/history returns assignment history" do
    conversation1 = Conversation.create!(
      title: "Conv 1",
      initiator: @questioner,
      status: "waiting"
    )
    conversation2 = Conversation.create!(
      title: "Conv 2",
      initiator: @questioner,
      status: "waiting"
    )
    
    assignment1 = ExpertAssignment.create!(
      conversation: conversation1,
      expert: @expert_user,
      status: "active",
      assigned_at: 2.hours.ago
    )
    assignment2 = ExpertAssignment.create!(
      conversation: conversation2,
      expert: @expert_user,
      status: "unassigned",
      assigned_at: 1.hour.ago
    )
    
    get "/expert/assignments/history",
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 2, response_data.length
    assert_equal assignment2.id.to_s, response_data.first["id"]
    assert_equal assignment1.id.to_s, response_data.last["id"]
  end

  test "GET /expert/assignments/history requires authentication" do
    get "/expert/assignments/history"
    assert_response :unauthorized
  end

  test "GET /expert/queue includes unreadCount for conversations" do
    conversation = Conversation.create!(
      title: "Test",
      initiator: @questioner,
      assigned_expert: @expert_user,
      status: "active"
    )
    Message.create!(
      conversation: conversation,
      user: @questioner,
      sender_role: "initiator",
      content: "Unread",
      is_read: false
    )
    
    get "/expert/queue", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assigned = response_data["assignedConversations"].first
    assert assigned.key?("unreadCount")
  end

  test "GET /expert/profile returns empty array for knowledge_base_links when nil" do
    @expert_profile.update!(knowledge_base_links: nil)
    
    get "/expert/profile", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal [], response_data["knowledgeBaseLinks"]
  end

  test "GET /expert/profile returns empty string for bio when nil" do
    @expert_profile.update!(bio: nil)
    
    get "/expert/profile", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal "", response_data["bio"]
  end
end