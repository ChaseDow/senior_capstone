class User < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :syllabuses, dependent: :destroy
  has_many :work_shifts, dependent: :destroy
  has_one :calendar_draft, dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { user: 0, admin: 1 }
  has_one_attached :avatar

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
end
