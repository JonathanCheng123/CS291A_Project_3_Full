module JwtAuthenticable
  extend ActiveSupport::Concern

  private

  def current_user_from_token
    return nil unless auth_header.present?
    
    token = auth_header.split(' ').last
    decoded = decode_token(token)
    return nil unless decoded

    @current_user_from_token ||= User.find_by(id: decoded['user_id'])
  end

  def authenticate_with_jwt!
    unless current_user_from_token
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def auth_header
    request.headers['Authorization']
  end

  def encode_token(payload)
    JWT.encode(payload, jwt_secret, 'HS256')
  end

  def decode_token(token)
    JWT.decode(token, jwt_secret, true, algorithm: 'HS256')[0]
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end

  def jwt_secret
    Rails.application.credentials.secret_key_base || 'your_secret_key'
  end

  def generate_token(user)
    encode_token({ user_id: user.id, exp: 24.hours.from_now.to_i })
  end
end