class HomeSecureController < SecureApplicationController

  # 
  # 
  def index
    @username, @senha = ActionController::HttpAuthentication::Basic::user_name_and_password(request)
  end
  
end
