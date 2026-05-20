Rails.application.routes.draw do
  # Auth
  get    "sign_in",  to: "sessions#new",         as: :new_session
  post   "sign_in",  to: "sessions#create",      as: :session
  delete "sign_out", to: "sessions#destroy"
  get    "sign_up",  to: "registrations#new",    as: :new_registration
  post   "sign_up",  to: "registrations#create", as: :registration
  resources :passwords, param: :token

  # App
  resources :documents, only: %i[index create edit update destroy]
  root "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
