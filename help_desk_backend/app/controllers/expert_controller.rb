class ExpertController < ApplicationController
    before_action :authenticate_with_jwt!
    before_action :ensure_expert_profile
  
    # GET /expert/queue
    def queue
      waiting = Conversation.where(status: 'waiting', assigned_expert_id: nil)
                            .order(created_at: :asc)
  
      assigned = Conversation.where(assigned_expert_id: current_expert.id, status: 'active')
                             .order(updated_at: :desc)
  
      render json: {
        waitingConversations: waiting.map { |c| queue_conversation_response(c) },
        assignedConversations: assigned.map { |c| queue_conversation_response(c) }
      }
    end
  
    # POST /expert/conversations/:conversation_id/claim
    def claim
      conversation = Conversation.find(params[:conversation_id])
  
      if conversation.assigned_expert_id.present?
        return render json: { error: 'Conversation is already assigned to an expert' },
                      status: :unprocessable_entity
      end
  
      ActiveRecord::Base.transaction do
        conversation.update!(assigned_expert: current_expert, status: 'active')
  
        ExpertAssignment.create!(
          conversation: conversation,
          expert: current_expert,
          status: 'active',
          assigned_at: Time.current
        )
      end
  
      render json: { success: true }
    end
  
    # POST /expert/conversations/:conversation_id/unclaim
    def unclaim
      conversation = Conversation.find(params[:conversation_id])
  
      if conversation.assigned_expert_id != current_expert.id
        return render json: { error: 'You are not assigned to this conversation' },
                      status: :forbidden
      end
  
      ActiveRecord::Base.transaction do
        assignment = conversation.expert_assignments.find_by(expert_id: current_expert.id, status: 'active')
        assignment&.update!(status: 'unassigned')
        conversation.update!(assigned_expert_id: nil, status: 'waiting')
      end
  
      render json: { success: true }
    end
  
    # GET /expert/profile
    def show_profile
      render json: profile_response(current_expert.expert_profile)
    end
  
    # PUT/PATCH /expert/profile
    def update_profile
      profile = current_expert.expert_profile
      # Map camelCase keys from frontend to Rails snake_case
      params[:knowledge_base_links] = params.delete(:knowledgeBaseLinks) if params[:knowledgeBaseLinks]
  
      if profile.update(profile_params)
        render json: profile_response(profile)
      else
        render json: { errors: profile.errors.full_messages }, status: :unprocessable_entity
      end
    end
  
    # GET /expert/assignments/history
    def assignment_history
      assignments = current_expert.expert_assignments.order(assigned_at: :desc)
      render json: assignments.map { |a| assignment_response(a) }
    end
  
    private
  
    # Authenticate request using JwtService
    def authenticate_with_jwt!
      header = request.headers['Authorization']
      token = header&.split(' ')&.last
      payload = JwtService.decode(token)
  
      if payload && (user = User.find_by(id: payload[:user_id]))
        @current_expert = user
      else
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
    end
  
    # Current authenticated expert
    def current_expert
      @current_expert
    end
  
    def ensure_expert_profile
      unless current_expert.expert_profile
        render json: { error: 'Expert profile not found' }, status: :forbidden
      end
    end
  
    def profile_params
      params.permit(:bio, knowledge_base_links: [])
    end
  
    def queue_conversation_response(conversation)
      {
        id: conversation.id.to_s,
        title: conversation.title,
        status: conversation.status,
        questionerId: conversation.initiator_id.to_s,
        questionerUsername: conversation.initiator&.username,
        assignedExpertId: conversation.assigned_expert_id&.to_s,
        assignedExpertUsername: conversation.assigned_expert&.username,
        createdAt: conversation.created_at.iso8601,
        updatedAt: conversation.updated_at.iso8601,
        lastMessageAt: conversation.last_message_at&.iso8601,
        unreadCount: conversation.unread_messages_for(current_expert)
      }
    end
  
    def profile_response(profile)
      return {} unless profile
  
      {
        id: profile.id.to_s,
        userId: profile.user_id.to_s,
        bio: profile.bio || "",
        knowledgeBaseLinks: profile.knowledge_base_links.presence || [],
        createdAt: profile.created_at&.iso8601,
        updatedAt: profile.updated_at&.iso8601
      }
    end
  
    def assignment_response(assignment)
      {
        id: assignment.id.to_s,
        conversationId: assignment.conversation_id.to_s,
        expertId: assignment.expert_id.to_s,
        status: assignment.status,
        assignedAt: assignment.assigned_at.iso8601,
        resolvedAt: assignment.resolved_at&.iso8601,
        rating: 5
      }
    end
  end
  