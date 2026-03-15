# frozen_string_literal: true

class NotificationsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.recent.includes(:notifiable).limit(30)
    @unread_count  = current_user.notifications.unread.count
    render layout: false
  end

  def destroy
    notification = current_user.notifications.find(params[:id])
    notification.destroy!

    remaining   = current_user.notifications.count
    unread_count = current_user.notifications.unread.count

    streams = [
      turbo_stream.remove(notification),
      turbo_stream.update(
        "notifications_panel_header",
        partial: "notifications/panel_header",
        locals: { unread_count: unread_count }
      ),
      turbo_stream.replace(
        "notification_badge",
        partial: "notifications/badge",
        locals: { unread_count: unread_count }
      )
    ]

    if remaining.zero?
      streams << turbo_stream.update("notifications_list", partial: "notifications/empty_state")
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: streams }
      format.html { redirect_back_or_to notifications_path }
    end
  end

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current)

    @notifications = current_user.notifications.recent.includes(:notifiable).limit(30)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            "notifications_panel",
            partial: "notifications/panel",
            locals: { notifications: @notifications, unread_count: 0 }
          ),
          turbo_stream.replace(
            "notification_badge",
            partial: "notifications/badge",
            locals: { unread_count: 0 }
          )
        ]
      end
      format.html { redirect_back_or_to notifications_path }
    end
  end
end
