class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :line

  def line
    @admin_user = AdminUser.from_omniauth(request.env["omniauth.auth"]) # request.env["omniauth.auth"] ⇒ https://github.com/kazasiki/omniauth-line

    if @admin_user.persisted?
      logger.debug "ログイン成功"
      sign_in_and_redirect @admin_user, event: :authentication # this will throw if @user is not activated
      set_flash_message(:notice, :success, kind: "LINE") if is_navigational_format?
    else
      logger.debug "ログイン失敗"
      session["devise.line_data"] = request.env["omniauth.auth"].except(:extra) # Removing extra as it can overflow some session stores
      redirect_to new_admin_user_session_path
    end
  end

  def failure
    redirect_to root_path
  end
end
