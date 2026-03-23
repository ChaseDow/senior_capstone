class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    user = User.from_omniauth(request.env["omniauth.auth"])

    if user == :unauthorized
      redirect_to new_user_session_path, alert: "The email address used is not associated with a supported university or is not a valid institutional email."
    elsif user.nil?
      redirect_to new_user_session_path, alert: "Google account email is not verified."
    elsif user.persisted?
      if user.confirmed?
        sign_in_and_redirect user, event: :authentication
        set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      else
        redirect_to new_user_session_path, notice: "A confirmation email has been sent to #{user.email}. Please confirm your account before signing in."
      end
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except("extra")
      redirect_to new_user_registration_url, alert: user.errors.full_messages.join("\n")
    end
  end

  def failure
    redirect_to root_path, alert: "Google authentication failed."
  end
end
