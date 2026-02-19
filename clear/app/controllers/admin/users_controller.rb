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

    private

    def require_admin
      unless current_user&.admin?
        redirect_to root_path, alert: "You are not authorized to access this page."
      end
    end
  end
end
