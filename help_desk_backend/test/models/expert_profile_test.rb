require "test_helper"

class ExpertProfileTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(username: "testuser", password: "password123")
    @profile = ExpertProfile.new(user: @user)
  end

  test "is valid with a user" do
    assert @profile.valid?
  end
  
  test "belongs to a user" do
    assert_equal @user, @profile.user
  end
end
