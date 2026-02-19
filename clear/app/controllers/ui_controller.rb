# frozen_string_literal: true

# This is used for testing UI pieces
class UiController < ApplicationController
  layout "app_shell"

  before_action :require_admin

  def show; end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end
end
