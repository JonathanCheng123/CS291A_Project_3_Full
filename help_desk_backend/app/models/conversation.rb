class Conversation < ApplicationRecord
    belongs_to :initiator, class_name: "User"
    belongs_to :assigned_expert, class_name: "User", optional: true
    has_many :messages
    has_many :expert_assignments
    validates :title, presence: true

    def unread_messages_for(user)
        messages.where(is_read: false).where.not(user_id: user.id).count
      end
end
  