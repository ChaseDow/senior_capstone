# Preview all emails at http://localhost:3000/rails/mailers/project_invitation_mailer
class ProjectInvitationMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/project_invitation_mailer/invite
  def invite
    ProjectInvitationMailer.invite
  end
end
