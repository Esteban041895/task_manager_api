class ApplicationController < ActionController::API
  before_action :set_current_user

  private

  def set_current_user
    user_id = request.headers["X-User-Id"]
    @current_user = User.find_by(id: user_id)

    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  attr_reader :current_user
end
