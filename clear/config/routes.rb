Rails.application.routes.draw do
  devise_for :users
  resource :profile, only: [ :show, :edit, :update ] do
    get :edit_password
    patch :update_password
  end

  resources :events
  resources :courses do
    resources :course_items, only: %i[index create edit update destroy]
  end
  resources :agenda

  resources :syllabuses do
    member do
      post :create_course
      get  :status
      get  :course_preview
      get  :course_preview_frame
      post :confirm_course
    end
  end

  # Admin-only pages (guarded in controllers via current_user.admin?)
  namespace :admin do
    resources :users, only: [ :index, :destroy ]
  end

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
  get "dashboard/agenda", to: "dashboard#agenda", as: :dashboard_agenda

  # Admin-only UI preview page (guarded in UiController)
  get "/ui", to: "ui#show"

  get "/schedule", to: "schedule#week"
  get "/schedule/week", to: "schedule#week"

  get "up" => "rails/health#show", as: :rails_health_check
end
