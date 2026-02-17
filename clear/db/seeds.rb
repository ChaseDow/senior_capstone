# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
require "securerandom"

puts "seeding..."

DEMO_EMAILS = %w[chase@example.com landon@example.com].freeze

if Rails.env.production? && ENV["SEED_DEMO_DATA"] != "true"
  puts "Skipping demo seed data in production."
  exit
end

demo_user_ids = User.where(email: DEMO_EMAILS).pluck(:id)
Event.where(user_id: demo_user_ids).delete_all
User.where(id: demo_user_ids).delete_all

now = Time.zone.now

users_data = [
  {
    email: "chase@example.com",
    password: ENV.fetch("DEMO_PASSWORD", SecureRandom.hex(16)),
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
        repeat_until: now + 14.day,
        title: "Gym",
        starts_at: now.change(hour: 16, min: 0) - 5.day,
        ends_at: now.change(hour: 17, min: 0) - 5.day,
        location: "Gym"
      }
    ]
  },
  {
    email: "landon@example.com",
    password: ENV.fetch("DEMO_PASSWORD", SecureRandom.hex(16)),
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
        repeat_until: now + 7.day,
        repeat_days: [ 2, 4 ],
        title: "Studying(Math)",
        starts_at: now.change(hour: 16, min: 0) - 4.day,
        ends_at: now.change(hour: 17, min: 0) - 4.day,
        location: "Home"
      }
    ]
  }
]

users_data.each do |u|
  events = u.delete(:events)
  user = User.create!(u)
  events.each { |e| user.events.create!(e) }
  puts "created user #{user.email} with #{events.size} events"
end

puts "DONE"
