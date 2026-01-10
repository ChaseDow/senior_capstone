Rails.application.routes.draw do
  devise_for :users
  resources :events


  if Rails.env.development?
    begin
      require "letter_opener_web"
      mount LetterOpenerWeb::Engine, at: "/letter_opener"
    rescue LoadError
    end
  end

  authenticated :user do
    root "dashboard#show", as: :authenticated_root
  end

  unauthenticated do
    root "home#index"
  end

  get "/dashboard", to: "dashboard#show"
  get "/ui", to: "ui#show"

  get "up" => "rails/health#show", as: :rails_health_check
end
