class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    render partial: "profiles/drawer_detail",
           locals: { user: @user }
  end

  def edit
    @user = current_user
    render partial: "profiles/drawer_detail",
           locals: { user: @user }
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
      flash.now[:alert] = "Current password is invalid."
      return render_profile_modal_with_toast(partial: "profiles/password_form", status: :unprocessable_entity)
    end

    # New password checker
    if password_params[:password].blank?
      @user.errors.add(:base, "New password can't be blank")
      flash.now[:alert] = "New password can't be blank."
      return render_profile_modal_with_toast(partial: "profiles/password_form", status: :unprocessable_entity)
    end

    # Password confirmation checker
    if password_params[:password_confirmation].blank?
      @user.errors.add(:base, "Password confirmation can't be blank")
      flash.now[:alert] = "Password confirmation can't be blank."
      return render_profile_modal_with_toast(partial: "profiles/password_form", status: :unprocessable_entity)
    end

    # New password == current password checker
    if @user.valid_password?(password_params[:password])
      @user.errors.add(:base, "New password must be different")
      flash.now[:alert] = "New password must be different from current password."
      return render_profile_modal_with_toast(partial: "profiles/password_form", status: :unprocessable_entity)
    end

    # Devise validation
    if @user.update_with_password(password_params)
      bypass_sign_in(@user)

      flash.now[:notice] = "Password updated."
      render_profile_modal_with_toast(partial: "profiles/drawer_detail")
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence.presence || "Couldn't update password."
      render_profile_modal_with_toast(partial: "profiles/password_form", status: :unprocessable_entity)
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
      return render_profile_modal_with_toast(partial: "profiles/drawer_detail")
    end

    if @user.update(avatar_params)
      flash.now[:notice] = "Successfully updated."
      render turbo_stream: [
        turbo_stream.replace(
          "profile_modal",
          partial: "profiles/drawer_detail",
          locals: { user: @user }
        ),
        turbo_stream.update(
          "left_nav_profile",
          partial: "profiles/left_nav_profile",
          locals: { user: @user }
        ),
        turbo_stream.replace("toast-container", partial: "shared/toasts")
      ]
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence.presence || "Couldn't update avatar."
      render_profile_modal_with_toast(partial: "profiles/edit_avatar_form", status: :unprocessable_entity)
    end
  end

  def avatar_params
    params.require(:user).permit(:avatar)
  end

  # form for deleting your account
  def delete_account
    @user = current_user
    render partial: "profiles/delete_account_form", locals: { user: @user }
  end

  def delete_params
    params.require(:user).permit(:current_password)
  end

  # deletes the account and all of its info
  def destroy_account
    @user = current_user

    unless @user.valid_password?(password_params[:password])
      @user.errors.add(:password, "is invalid")
      flash.now[:alert] = "Password is invalid."
      return render_profile_modal_with_toast(partial: "profiles/delete_account_form", status: :unprocessable_entity)
    end

    @user.destroy!
    sign_out(@user)
    redirect_to root_path, notice: "Account Successfully Deleted"
  end

  def render_profile_modal_with_toast(partial:, status: :ok)
    render turbo_stream: [
      turbo_stream.replace(
        "profile_modal",
        partial: partial,
        locals: { user: @user }
      ),
      turbo_stream.replace("toast-container", partial: "shared/toasts")
    ], status: status
  end
end
