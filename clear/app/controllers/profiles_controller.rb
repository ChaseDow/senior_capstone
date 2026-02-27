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

    # Current password checker
    unless @user.valid_password?(password_params[:current_password])
      @user.errors.add(:current_password, "is invalid")
      return render partial: "profiles/password_form", locals: { user: @user }, status: :unprocessable_entity
    end

    # New password checker
    if password_params[:password].blank?
      @user.errors.add(:base, "New password can't be blank")
      return render partial: "profiles/password_form", locals: { user: @user }, status: :unprocessable_entity
    end

    # Password confirmation checker
    if password_params[:password_confirmation].blank?
      @user.errors.add(:base, "Password confirmation can't be blank")
      return render partial: "profiles/password_form", locals: { user: @user }, status: :unprocessable_entity
    end

    # New password == current password checker
    if @user.valid_password?(password_params[:password])
      @user.errors.add(:base, "New password must be different")
      return render partial: "profiles/password_form", locals: { user: @user }, status: :unprocessable_entity
    end

    # Devise validation
    if @user.update_with_password(password_params)
      bypass_sign_in(@user)

      flash.now[:notice] = "Password updated."
      render partial: "profiles/drawer_detail", locals: { user: @user }
    else
      render partial: "profiles/password_form", locals: { user: @user }, status: :unprocessable_entity
    end
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def edit_avatar
    @user = current_user
    render partial: "profiles/edit_avatar_form", locals: { user: @user }
  end

  def update_avatar
    @user = current_user

    # If user hit Save without selecting a file, just show the drawer again
    unless params.dig(:user, :avatar).present?
      flash.now[:notice] = "No changes to save."
      return render partial: "profiles/drawer_detail", locals: { user: @user }
    end

    if @user.update(avatar_params)
      flash.now[:notice] = "Successfully updated."
      render partial: "profiles/drawer_detail", locals: { user: @user }
    else
      render partial: "profiles/edit_avatar_form",
        locals: { user: @user },
        status: :unprocessable_entity
    end
  end

  def avatar_params
    params.require(:user).permit(:avatar)
  end
end
