require "test_helper"

class ProjectInvitationMailerTest < ActionMailer::TestCase
  test "invite" do
    invitation = project_invitations(:one)
    mail = ProjectInvitationMailer.invite(invitation)
    assert_equal "You've been invited to \"#{invitation.project.title}\"", mail.subject
    assert_equal [ invitation.email ], mail.to
    assert_match invitation.token, mail.body.encoded
  end
end
