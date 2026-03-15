Rails.application.routes.draw do
  devise_for :users

  resource :profile, only: [ :show, :edit, :update ] do
    get :edit_password
    patch :update_password
    get :edit_avatar
    patch :update_avatar
  end

  # Theme
  resource :theme, only: [ :update ] do
    delete :reset, on: :member
  end

  resources :events do
    collection do
      delete :destroy_all
    end
  end

  scope :university_calendar do
    get  "preview", to: "university_calendar#preview", as: :university_calendar_preview
    post "import",  to: "university_calendar#import",  as: :university_calendar_import
  end
  resources :courses do
    resources :course_items, only: %i[index create show edit update destroy]
  end
  resources :agenda

  resources :syllabuses do
    member do
      post :create_course
      get  :status
      get  :course_preview
      get  :course_preview_frame
      post :confirm_course
      get  :course_items_preview
      post :confirm_course_items
    end
  end

  resources :ai_chat, only: [ :index, :create ]

  resources :notifications, only: [ :index, :destroy ] do
    collection do
      patch :mark_all_read
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

  get "/dashboard",       to: "dashboard#show"
  get "dashboard/agenda", to: "dashboard#agenda", as: :dashboard_agenda

  post   "dashboard/draft",         to: "draft#enter",   as: :enter_draft
  patch  "dashboard/draft/apply",   to: "draft#apply",   as: :apply_draft
  delete "dashboard/draft",         to: "draft#discard", as: :discard_draft

  get "/ui",             to: "ui#show"
  get "/schedule",       to: "schedule#week"
  get "/schedule/week",  to: "schedule#week"

  get "up" => "rails/health#show", as: :rails_health_check
end
