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
end
