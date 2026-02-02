# frozen_string_literal:true

# This is used for testing UI pieces
class UiController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def show
  end
end
