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
  resources :collections, only: %i[index show create update destroy] do
    # Add an existing doc to / remove it from a collection (membership only).
    resources :documents, only: %i[create destroy], controller: "collection_documents"
  end
  resources :tasks, only: %i[index show create update destroy] do
    collection do
      post :reorder  # drag-and-drop persistence: { status:, ids: [] }
    end
    resources :comments, only: %i[create], controller: "task_comments"
    resources :documents, only: %i[create destroy], controller: "task_documents"
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
      resources :collections, only: %i[index create show update destroy] do
        # POST attaches an existing doc (document_id) or, given a markdown
        # body, creates a new doc and attaches it — the agent publish path.
        # DELETE detaches a doc (:id is the document's public_token).
        resources :documents, only: %i[create destroy], controller: "collection_documents"
      end
      resources :tasks, only: %i[index create show update destroy] do
        # Agents comment on a task and link documents they produced for it.
        resources :comments, only: %i[create], controller: "task_comments"
        resources :documents, only: %i[create destroy], controller: "task_documents"
      end
    end
  end

  # Public share routes (no auth). Both formats use the same path.
  get "/d/:token", to: "public_documents#show", as: :public_document, constraints: { token: /[A-Za-z0-9]+/ }

  root "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
