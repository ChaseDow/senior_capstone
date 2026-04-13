class ProjectMessagesController < ApplicationController
  before_action :authenticate_user!
  def create
    @project = Project.find(params[:project_id])
    @message = @project.project_messages.build(message_params)
    @message.user = current_user

    if @message.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @project }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @project, alert: "Message can't be blank. " }
      end
    end
  end

  private

  def message_params
    params.require(:project_message).permit(:body)
  end
end
