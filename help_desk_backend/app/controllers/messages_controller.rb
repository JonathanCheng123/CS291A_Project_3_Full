class MessagesController < ApplicationController
  before_action :authenticate_with_jwt!
  before_action :set_conversation, only: [:index, :create]
  before_action :authorize_conversation!, only: [:create, :read]
  before_action :set_message, only: [:read]

  # GET /conversations/:conversation_id/messages
  def index
    messages = @conversation.messages.order(created_at: :asc)
    render json: messages.map { |m| message_response(m) }
  end

  # POST /messages
  def create
    message = @conversation.messages.new(message_params)
    message.user = current_user_from_token
    message.sender_role = current_user_from_token.id == @conversation.initiator_id ? 'initiator' : 'expert'

    if message.save
      render json: message_response(message), status: :created
    else
      render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /messages/:id/read
  def read
    if @message.user_id == current_user_from_token.id
      return render json: { error: 'Cannot mark your own messages as read' }, status: :forbidden
    end

    @message.update!(is_read: true)
    render json: { success: true }
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
  def current_user_from_token
    @current_user
  end

  def set_conversation
    @conversation = Conversation.find(params[:conversationId] || params[:conversation_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Conversation not found' }, status: :not_found
  end

  def authorize_conversation!
    unless @conversation.initiator_id == current_user_from_token.id || 
           @conversation.assigned_expert_id == current_user_from_token.id
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end

  def set_message
    @message = Message.find(params[:id])
    unless @message.conversation.initiator_id == current_user_from_token.id || 
           @message.conversation.assigned_expert_id == current_user_from_token.id
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end

  def message_params
    params.permit(:content)
  end

  def message_response(message)
    {
      id: message.id.to_s,
      conversationId: message.conversation_id.to_s,
      senderId: message.user_id.to_s,
      senderUsername: message.user.username,
      senderRole: message.sender_role,
      content: message.content,
      timestamp: message.created_at.iso8601,
      isRead: message.is_read
    }
  end
end
