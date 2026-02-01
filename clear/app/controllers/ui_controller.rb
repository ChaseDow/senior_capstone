# frozen_string_literal:true

# This is used for testing UI pieces
class UiController < ApplicationController
  before_action :require_dev

private

def require_dev
  unless current_user&.dev_account?
    redirect_to root_path, alert: "You are not authorized to access this page."
  end
end
  def show; end
end
