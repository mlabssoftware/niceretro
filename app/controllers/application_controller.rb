class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.

  include HttpAuthConcern
  http_basic_authenticate_with name: ENV["nice_user"], password: ENV["nice_pass"]

  protect_from_forgery with: :exception

  helper_method :current_team

  def current_team
    Team.find(params[:team_id]) if params[:team_id].present?
  end
end
