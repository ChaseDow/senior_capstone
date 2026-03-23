class ProjectInvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @project = invitation.project
    @sender = invitation.sender
    @accept_url = accept_project_invitation_url(token: invitation.token)

    mail(to: invitation.email, subject: "You've been invited to \"#{@project.title}\"")
  end
end
