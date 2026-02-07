class ProfilesController < ApplicationController
  before_action :authenticate_user!
  def show
    @user = current_user

    return unless turbo_frame_request?

    render partial: "profiles/drawer_detail",
           locals: { user: @user }
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
  end

  def edit_password
    @user = current_user
    render partial: "profiles/password_form", locals: { user: @user }
  end

  def update_password
    @user = current_user


    if @user.update_with_password(password_params)
      bypass_sign_in(@user)

      flash.now[:notice] = "Password updated."
      render partial: "profiles/drawer_detail", locals: { user: @user }
    else
      render partial: "profiles/password_form", locals: { user: @user }, statues: :unprocessable_entity
    end
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
