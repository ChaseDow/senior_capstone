Rails.application.routes.draw do
  devise_for :users
  resource :profile, only: [ :show, :edit, :update ] do
    get :edit_password
    patch :update_password
    get :edit_avatar
    patch :update_avatar
  end

  resources :events
  resources :courses do
    resources :course_items, only: %i[index create edit update destroy]
  end
  resources :agenda

  # Drafts for "what-if" simulation / bulk edits
  resources :calendar_drafts, only: %i[create index] do
    member do
      post :apply
      post :discard
    end

    resources :calendar_draft_operations, only: %i[update destroy] do
      member do
        post :accept
        post :reject
      end
    end
  end

  # Draft-mode write endpoints (used when viewing a draft)
  namespace :draft_mode do
    resources :events, only: %i[create update destroy]
    resources :course_items, only: %i[create update destroy]
  end

  resources :syllabuses do
    member do
      post :create_course
      get  :status
      get  :course_preview
      get  :course_preview_frame
      post :confirm_course
    end
  end

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

  get "/ui", to: "ui#show"

  get "/schedule", to: "schedule#week"
  get "/schedule/week", to: "schedule#week"

  get "up" => "rails/health#show", as: :rails_health_check
end
