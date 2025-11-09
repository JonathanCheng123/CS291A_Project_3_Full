class Message < ApplicationRecord
    belongs_to :user
    belongs_to :conversation
  
    validates :content, presence: true
    validates :sender_role, presence: true, inclusion: { in: ['initiator', 'expert'] }
  
    def mark_as_read!
      update!(is_read: true)
    end
  end