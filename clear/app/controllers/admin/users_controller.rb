# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    layout "app_shell"
    before_action :require_admin

    def index
      @users = User.order(created_at: :desc)
    end


    def destroy
      user = User.find(params[:id])

      if user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account." and return
      end

      user.destroy!
      redirect_to admin_users_path, notice: "User deleted."
    end

    def edit_password
      @user = User.find(params[:id])
    end

    def update_password
      @user = User.find(params[:id])

      if admin_password_params[:password].blank?
        @user.errors.add(:password, "can't be blank")
        flash.now[:alert] = "Password can't be blank."
        return render :edit_password, status: :unprocessable_entity
      end

      if admin_password_params[:password] != admin_password_params[:password_confirmation]
        @user.errors.add(:password_confirmation, "doesn't match password")
        flash.now[:alert] = "Passwords don't match."
        return render :edit_password, status: :unprocessable_entity
      end

      if @user.update(password: admin_password_params[:password], password_confirmation: admin_password_params[:password_confirmation])
        redirect_to admin_users_path, notice: "Password updated for #{@user.email}."
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence.presence || "Couldn't update password."
        render :edit_password, status: :unprocessable_entity
      end
    end

    private

    def require_admin
      unless current_user&.admin?
        redirect_to root_path, alert: "You are not authorized to access this page."
      end
    end

    def admin_password_params
      params.require(:user).permit(:password, :password_confirmation)
    end
  end
end
