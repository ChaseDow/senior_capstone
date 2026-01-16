# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

puts "seeding..."
Event.destroy_all
User.destroy_all
now = Time.zone.now
users_data = [
    {
        email: "chase@example.com",
        password: "password123",
        events: [
            {
                color: "#FFA500",
                title: "Capstone Standup",
                starts_at: now.change(hour: 9, min: 0)+1.day,
                ends_at: now.change(hour: 10, min: 30)+1.day,
                location: "Discord",
                description: "Quick daily standup"
            },
            {
                recurring: true,
                repeat_days: [
                    1,
                    3,
                    5
                ],
                repeat_until: now+14.day,
                title: "Gym",
                starts_at: now.change(hour: 16, min:0)-5.day,
                ends_at: now.change(hour: 17, min: 0)-5.day,
                location: "Gym"
            }
        ]
    },
    {
        email: "landon@example.com",
        password: "password123",
        events: [
            {
                color: "#FFFFFF",
                title: "Capstone Standdown",
                starts_at: now.change(hour: 9, min: 0)+1.day,
                ends_at: now.change(hour: 10, min: 30)+1.day,
                location: "Discord",
                description: "Quick daily standup"
            },
            {
                color: "#000000",
                recurring: true,
                repeat_until: now+7.day,
                repeat_days: [
                    2,
                    4
                ],
                title: "Gym",
                starts_at: now.change(hour: 16, min:0)-4.day,
                ends_at: now.change(hour: 17, min: 0)-4.day,
                location: "Gym"
            }
        ]
    }
]
users_data.each do |u|
    events = u.delete(:events)
    user = User.create!(u)
    events.each do |e|
        user.events.create!(e)
    end
    puts "created user #{user.email} with #{events.size} events"
end
puts "DONE"