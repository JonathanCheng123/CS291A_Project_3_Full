class AuthController < ApplicationController
  include SessionAuthenticable

  before_action :authenticate_with_session!, only: [:refresh, :me]

  def register
    user = User.new(user_params)
    
    if user.save
      ExpertProfile.create!(user_id: user.id)
      session[:user_id] = user.id
      user.update!(last_active_at: Time.current)
      token = JwtService.encode(user)
      
      render json: { user: user_response(user), token: token }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(username: params[:username])
    if user&.authenticate(params[:password])
      ActiveRecord::SessionStore::Session.delete_all
      session[:user_id] = user.id
      user.update!(last_active_at: Time.current)
      token = JwtService.encode(user)
      
      render json: { user: user_response(user), token: token }
    else
      render json: { error: 'Invalid username or password' }, status: :unauthorized
    end
  end

  def logout
    reset_session
    render json: { message: 'Logged out successfully' }
  end

  def refresh
    user = current_user_from_session
    user.update!(last_active_at: Time.current)
    token = JwtService.encode(user)
    
    render json: { user: user_response(user), token: token }
  end

  def me
    render json: user_response(current_user_from_session)
  end

  private

  def user_params
    params.permit(:username, :password)
  end

  def user_response(user)
    {
      id: user.id,
      username: user.username,
      created_at: user.created_at.iso8601,
      last_active_at: user.last_active_at&.iso8601
    }
  end
end
