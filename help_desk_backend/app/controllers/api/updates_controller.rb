class Api::UpdatesController < ApplicationController
  before_action :require_user_id, only: [:conversations, :messages]
  before_action :require_expert_id, only: [:expert_queue]

  # GET /api/conversations/updates
  def conversations
    since = parse_timestamp(params[:since])
    user_id = params[:userId]

    conversations = Conversation
                      .includes(:initiator, :assigned_expert)
                      .where("initiator_id = :id OR assigned_expert_id = :id", id: user_id)

    conversations = conversations.where("updated_at > ?", since) if since.present?

    render json: conversations.map { |c| conversation_json(c, user_id) }
  end

  # GET /api/messages/updates
  def messages
    since = parse_timestamp(params[:since])
    user_id = params[:userId]

    messages = Message.includes(:user, :conversation)
    messages = messages.where("messages.created_at > ?", since) if since.present?

    messages = messages.joins(:conversation)
                       .where("conversations.initiator_id = :id OR conversations.assigned_expert_id = :id", id: user_id)

    render json: messages.map { |m| message_json(m, user_id) }
  end

  # GET /api/expert-queue/updates
  def expert_queue
    since = parse_timestamp(params[:since])
    expert_id = params[:expertId]

    waiting = Conversation.waiting
    waiting = waiting.where("updated_at > ?", since) if since.present?

    assigned = Conversation.where(assigned_expert_id: expert_id)
    assigned = assigned.where("updated_at > ?", since) if since.present?

    render json: {
      waitingConversations: waiting.map { |c| conversation_json(c, expert_id) },
      assignedConversations: assigned.map { |c| conversation_json(c, expert_id) }
    }
  end

  private

  def require_user_id
    render json: { error: "userId is required" }, status: :bad_request unless params[:userId].present?
  end

  def require_expert_id
    render json: { error: "expertId is required" }, status: :bad_request unless params[:expertId].present?
  end

  def parse_timestamp(ts)
    return nil unless ts.present?
    Time.iso8601(ts) rescue nil
  end

  # JSON builders
  def conversation_json(c, user_id)
    {
      id: c.id.to_s,
      title: c.title,
      status: c.status,
      questionerId: c.initiator_id.to_s,
      questionerUsername: c.initiator&.username,
      assignedExpertId: c.assigned_expert_id&.to_s,
      assignedExpertUsername: c.assigned_expert&.username,
      createdAt: c.created_at.iso8601,
      updatedAt: c.updated_at.iso8601,
      lastMessageAt: c.last_message_at&.iso8601,
      unreadCount: c.messages.where(is_read: false).where.not(user_id: user_id).count
    }
  end

  def message_json(m, user_id)
    {
      id: m.id.to_s,
      conversationId: m.conversation_id.to_s,
      senderId: m.user_id.to_s,
      senderUsername: m.user&.username,
      senderRole: m.sender_role,
      content: m.content,
      timestamp: m.created_at.iso8601,
      isRead: m.is_read
    }
  end
end
