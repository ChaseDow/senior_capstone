class User < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :syllabuses, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :work_shifts, dependent: :destroy
  has_one :calendar_draft, dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  ALLOWED_DOMAINS = %w[email.latech.edu].freeze

  enum :role, { user: 0, admin: 1 }
  has_one_attached :avatar

  # ── Theme ────────────────────────────────────────────────
  THEMES = %w[green blue purple rose amber cyan pink red lime slate orange].freeze
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

    domain = auth.info.email.downcase.split("@").last
    return :unauthorized unless ALLOWED_DOMAINS.include?(domain)

    user = find_by(provider: auth.provider, uid: auth.uid)
    user ||= find_by(email: auth.info.email)

    if user
      user.update(provider: auth.provider, uid: auth.uid)
    else
      user = create(
        email:    auth.info.email,
        password: Devise.friendly_token[0, 20],
        provider: auth.provider,
        uid:      auth.uid
      )
    end

    user
  end

  def password_required?
    super && provider.blank?
  end

  validate :email_domain_allowed

  def email_domain_allowed
    domain = email.to_s.downcase.split("@").last
    unless ALLOWED_DOMAINS.include?(domain)
      errors.add(:email, "is not associated with a supported university or is not a valid institutional email")
    end
  end
end
