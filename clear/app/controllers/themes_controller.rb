# app/controllers/themes_controller.rb
class ThemesController < ApplicationController
  before_action :authenticate_user!

  def update
    if current_user.update_theme(theme_params)
      redirect_back fallback_location: authenticated_root_path, notice: "Theme saved!"
    else
      redirect_back fallback_location: authenticated_root_path, alert: "Couldn't save theme."
    end
  end

  def reset
    current_user.update(theme: User::THEME_DEFAULT)
    redirect_back fallback_location: authenticated_root_path, notice: "Theme reset."
  end

  private

  def theme_params
    params.require(:theme).permit(:theme)
  end
end
