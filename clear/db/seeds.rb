# db/seeds.rb
require "securerandom"

puts "seeding..."

# ----------------------------
# Admin seed (ALL environments)
# ----------------------------
ADMIN_EMAIL = ENV.fetch("ADMIN_EMAIL", "admin@clearplanner.app")

admin_password =
  if Rails.env.production?
    ENV.fetch("ADMIN_PASSWORD") # REQUIRED in production
  else
    # Local default if you don't set ADMIN_PASSWORD
    ENV.fetch("ADMIN_PASSWORD", "ClearPlanner!2026-DevTeam#1")
  end

admin = User.find_or_initialize_by(email: ADMIN_EMAIL)
admin.password = admin_password
admin.password_confirmation = admin_password

# Works if you added enum role: { user: 0, admin: 1 }
# If you haven't migrated role yet, this will raise (which is good — forces consistency).
admin.role = :admin

admin.save!
puts "Ensured admin account: #{admin.email}"

# ------------------------------------
# Demo seed (LOCAL only unless opt-in)
# ------------------------------------
seed_demo_data = if Rails.env.production?
  ENV["SEED_DEMO_DATA"] == "true"
else
  # seed demo users in development by default, can disable with SEED_DEMO_DATA=false
  ENV.fetch("SEED_DEMO_DATA", "true") == "true"
end

unless seed_demo_data
  puts "Skipping demo seed data."
  puts "DONE"
  exit
end

DEMO_EMAILS = %w[chase@example.com landon@example.com].freeze

# Clean slate for demo users (idempotent)
demo_user_ids = User.where(email: DEMO_EMAILS).pluck(:id)
Event.where(user_id: demo_user_ids).delete_all
User.where(id: demo_user_ids).delete_all

now = Time.zone.now
demo_password = ENV.fetch("DEMO_PASSWORD", SecureRandom.hex(16))

users_data = [
  {
    email: "chase@example.com",
    password: demo_password,
    role: :user,
    events: [
      {
        color: "#FFA500",
        title: "Capstone Sprint planning",
        starts_at: now.change(hour: 9, min: 0) + 1.day,
        ends_at: now.change(hour: 10, min: 30) + 1.day,
        location: "Discord",
        description: "Plan Sprint 2"
      },
      {
        recurring: true,
        repeat_days: [ 1, 3, 5 ],
        repeat_until: now + 14.days,
        title: "Gym",
        starts_at: now.change(hour: 16, min: 0) - 5.days,
        ends_at: now.change(hour: 17, min: 0) - 5.days,
        location: "Gym"
      }
    ]
  },
  {
    email: "landon@example.com",
    password: demo_password,
    role: :user,
    events: [
      {
        color: "#FFFFFF",
        title: "Sprint planning for Capstone",
        starts_at: now.change(hour: 9, min: 0) + 1.day,
        ends_at: now.change(hour: 10, min: 30) + 1.day,
        location: "Discord",
        description: "Planning second sprint for capstone class."
      },
      {
        color: "#FF0000",
        recurring: true,
        repeat_until: now + 7.days,
        repeat_days: [ 2, 4 ],
        title: "Studying(Math)",
        starts_at: now.change(hour: 16, min: 0) - 4.days,
        ends_at: now.change(hour: 17, min: 0) - 4.days,
        location: "Home"
      }
    ]
  }
]

users_data.each do |u|
  events = u.delete(:events)
  user = User.create!(u)
  events.each { |e| user.events.create!(e) }
  puts "Created demo user #{user.email} with #{events.size} events"
end

puts "DONE"
