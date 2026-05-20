Rails.application.routes.draw do
  # Auth
  get    "sign_in",  to: "sessions#new",         as: :new_session
  post   "sign_in",  to: "sessions#create",      as: :session
  delete "sign_out", to: "sessions#destroy"
  get    "sign_up",  to: "registrations#new",    as: :new_registration
  post   "sign_up",  to: "registrations#create", as: :registration
  resources :passwords, param: :token

  # App
  resources :documents, only: %i[index create edit update destroy] do
    member do
      post :preview
    end
    resource :share, only: %i[create destroy], controller: "shares"
  end
  resources :tags, only: %i[index]

  namespace :settings do
    resources :api_tokens, only: %i[index create destroy]
  end

  # JSON / markdown API
  namespace :api do
    namespace :v1 do
      resources :documents, only: %i[index create show update destroy] do
        resource :content, only: %i[show update]
      end
    end
  end

  # Public share routes (no auth). Both formats use the same path.
  get "/d/:token", to: "public_documents#show", as: :public_document, constraints: { token: /[A-Za-z0-9]+/ }

  root "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
