require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(username: "testing", password: "password123", password_confirmation: "password123")
  end

  test "should be valid with valid attributes" do
    assert @user.valid?
  end

  test "username should be present" do
    @user.username = ""
    assert_not @user.valid?
  end

  test "username should be unique" do
    duplicate_user = @user.dup
    @user.save
    assert_not duplicate_user.valid?
  end

  test "password should be present on create" do
    @user.password = @user.password_confirmation = ""
    assert_not @user.valid?
  end

  test "password should have a minimum length" do
    @user.password = @user.password_confirmation = "short"
    assert_not @user.valid?
  end

  test "authenticate should return the user for correct password" do
    @user.save
    assert_equal @user, @user.authenticate("password123")
  end

  test "authenticate should return false for incorrect password" do
    @user.save
    assert_not @user.authenticate("wrongpassword")
  end
end
