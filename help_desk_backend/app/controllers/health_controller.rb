class HealthController < ApplicationController
    # show should occur without authentication
    
    def show
        render json: {
        status: 'ok',
        timestamp: Time.current.iso8601
        }
    end
end
