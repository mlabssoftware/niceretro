class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :current_team

  def current_team
    Team.find(params[:team_id]) if params[:team_id].present?
  http_basic_authenticate_with name: 'mlabs', password: 'mL4b$nice'
  end
end
