class User < ApplicationRecord
    # Adds methods to set and authenticate against a BCrypt password
    has_secure_password
    has_many :messages
    has_one :expert_profile, dependent: :destroy
    has_many :expert_assignments, foreign_key: :expert_id, class_name: 'ExpertAssignment'
    
    validates :username, presence: true, uniqueness: true
    validates :password, presence: true, length: { minimum: 6 }, on: :create
  end