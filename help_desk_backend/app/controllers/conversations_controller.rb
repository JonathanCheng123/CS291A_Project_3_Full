class ConversationsController < ApplicationController
  before_action :authenticate_with_jwt!, only: [:index, :show, :create]
  before_action :set_conversation, only: [:show]

  # GET /conversations
  def index
    conversations = Conversation.where(initiator_id: current_user.id)
                                .or(Conversation.where(assigned_expert_id: current_user.id))
                                .order(updated_at: :desc)

    render json: conversations.map { |c| conversation_response(c) }
  end

  # GET /conversations/:id
  def show
    render json: conversation_response(@conversation)
  end

  # POST /conversations
  def create
    conversation = Conversation.new(conversation_params)
    conversation.initiator = current_user

    if conversation.save
      render json: conversation_response(conversation), status: :created
    else
      render json: { errors: conversation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Authenticate request with JWT
  def authenticate_with_jwt!
    header = request.headers['Authorization']
    token = header&.split(' ')&.last
    payload = JwtService.decode(token)

    if payload && (user = User.find_by(id: payload[:user_id]))
      @current_user = user
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  # Returns current user from JWT
  def current_user
    @current_user
  end

  # Set conversation for show
  def set_conversation
    @conversation = Conversation.find(params[:id])
    unless @conversation.initiator_id == current_user.id || 
           @conversation.assigned_expert_id == current_user.id
      render json: { error: 'Conversation not found' }, status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Conversation not found' }, status: :not_found
  end

  # Strong parameters
  def conversation_params
    params.permit(:title) # flat params compatible with your tests
  end

  # JSON response for a conversation
  def conversation_response(conversation)
    {
      id: conversation.id.to_s,
      title: conversation.title,
      status: conversation.status,
      questionerId: conversation.initiator_id.to_s,
      questionerUsername: conversation.initiator.username,
      assignedExpertId: conversation.assigned_expert_id&.to_s,
      assignedExpertUsername: conversation.assigned_expert&.username,
      createdAt: conversation.created_at.iso8601,
      updatedAt: conversation.updated_at.iso8601,
      lastMessageAt: conversation.last_message_at&.iso8601,
      unreadCount: conversation.unread_messages_for(current_user)
    }
  end
end
