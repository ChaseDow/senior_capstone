class User < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :syllabuses, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :work_shifts, dependent: :destroy
  has_one :calendar_draft, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :owned_projects, class_name: "Project", dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :projects, through: :project_memberships
  has_many :sent_project_invitations, class_name: "ProjectInvitation", foreign_key: :sender_id, dependent: :destroy

  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]


  enum :role, { user: 0, admin: 1 }
  has_one_attached :avatar
  validates :username, length: { in: 2..32 }

  # ── Theme ────────────────────────────────────────────────
  THEMES = %w[green blue purple rose amber cyan pink red lime slate orange mono nebula aurora sunset latech].freeze
  THEME_DEFAULT = "green".freeze

  def theme
    THEMES.include?(super) ? super : THEME_DEFAULT
  end

  def update_theme(params)
    theme_name = params[:theme].to_s
    update(theme: THEMES.include?(theme_name) ? theme_name : THEME_DEFAULT)
  end
  # ─────────────────────────────────────────────────────────

  def avatar_thumbnail
    avatar.variant(resize: "150x150!").processed
  end

  def self.from_omniauth(auth)
    return nil unless auth.info.email_verified

    user = find_by(provider: auth.provider, uid: auth.uid)
    user ||= find_by(email: auth.info.email)

    if user
      user.skip_confirmation!
      user.update(provider: auth.provider, uid: auth.uid)
    else
      user = create(
        email:    auth.info.email,
        password: Devise.friendly_token[0, 20],
        provider: auth.provider,
        uid:      auth.uid
      )
      user.skip_confirmation!
      user.save
    end

    user
  end

  def password_required?
    super && provider.blank?
  end

  def confirmation_required?
    super && provider.blank?
  end
end
