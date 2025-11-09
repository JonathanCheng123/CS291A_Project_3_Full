class ExpertAssignment < ApplicationRecord
    belongs_to :conversation
    belongs_to :expert, class_name: "User", foreign_key: :expert_id
 end