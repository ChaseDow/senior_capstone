class ProjectInvitationsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_project, only: %i[new create]

  def new
    @invitation = @project.project_invitations.new
  end

  def create
    @invitation = @project.project_invitations.new(invitation_params)
    @invitation.sender = current_user

    if @invitation.save
      ProjectInvitationMailer.invite(@invitation).deliver_later
      redirect_to project_path(@project), notice: "Invitation sent to #{@invitation.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def accept
    invitation = ProjectInvitation.find_by(token: params[:token])

    if invitation.nil?
      redirect_to root_path, alert: "Invalid invitation link."
      return
    end

    if invitation.accepted?
      redirect_to project_path(invitation.project), notice: "This invitation has already been accepted."
      return
    end

    invitation.accept!(current_user)
    redirect_to project_path(invitation.project), notice: "You joined \"#{invitation.project.title}\"!"
  end

  private

  def set_project
    @project = current_user.projects.find_by(id: params[:project_id])
    unless @project
      redirect_to projects_path, alert: "Project not found or you are not a member."
    end
  end

  def invitation_params
    params.require(:project_invitation).permit(:email)
  end
end
