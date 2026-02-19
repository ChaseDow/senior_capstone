# frozen string literal: true

class Profile < ApplicationRecord
    has_one_attached :image 
end
