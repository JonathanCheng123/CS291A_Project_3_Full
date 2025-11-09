module SessionAuthenticable
  extend ActiveSupport::Concern

  private

  def current_user_from_session
    return nil unless session[:user_id]
    @current_user_from_session ||= User.find_by(id: session[:user_id])
  end

  def authenticate_with_session!
    unless current_user_from_session
      render json: { error: 'No session found' }, status: :unauthorized
    end
  end

  def set_session(user)
    session[:user_id] = user.id
  end

  def clear_session
    session.delete(:user_id)
  end
end