require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "GET /health returns ok status" do
    get "/health"
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal "ok", response_data["status"]
  end

  test "GET /health returns timestamp" do
    get "/health"
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert response_data.key?("timestamp")
    assert_not_nil response_data["timestamp"]
  end

  test "GET /health does not require authentication" do
    get "/health"
    assert_response :ok
  end

  test "GET /health timestamp is in ISO8601 format" do
    get "/health"
    assert_response :ok
    response_data = JSON.parse(response.body)
    timestamp = response_data["timestamp"]
    
    # Verify it can be parsed as a valid ISO8601 datetime
    assert_nothing_raised do
      DateTime.iso8601(timestamp)
    end
  end

  test "GET /health returns correct JSON structure" do
    get "/health"
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 2, response_data.keys.length
    assert response_data.key?("status")
    assert response_data.key?("timestamp")
  end
end