# config/routes.rb
Rails.application.routes.draw do
  # --- SITE PUBLIC ---

  # Page d’accueil
  root "pages#home"

  # Opportunités
  resources :opportunities, only: %i[index show new create] do
    collection do
      # Page de remerciement après validation d’une proposition
      get :merci
    end
  end

  # Parcours : filtre par catégorie (ex. /parcours/benevolat)
  get "/parcours/:category", to: "opportunities#index", as: :parcours

  # Pages éditoriales
  get "philosophie", to: "pages#philosophie", as: :philosophie
  get "sponsors",    to: "pages#sponsors",    as: :sponsors

  # Histoires
  resources :stories, only: %i[index show new create]

  # Mentions légales / infos
  get "/mentions-legales", to: "pages#legal",           as: :mentions_legales
  get "/confidentialite",  to: "pages#confidentialite", as: :confidentialite
  get "/presse",           to: "pages#presse",          as: :presse
  get "/faq",              to: "pages#faq",             as: :faq

  # --- API PUBLIQUE ---

  namespace :api do
    namespace :v1 do
      resources :opportunities, only: %i[index show]
      resources :stories,       only: %i[index]
    end
  end

  if Rails.env.development?
  mount LetterOpenerWeb::Engine, at: "/letter_opener"
end

  # --- ADMIN ---

  namespace :admin do
    root to: "opportunities#index"

    resources :opportunities, only: %i[index edit update destroy] do
      member do
        patch :toggle_active      # Activer / désactiver une opportunité
      end
      collection do
        post :bulk                # Actions groupées (activate/deactivate/destroy)
        post :geocode_missing     # Géocodage des opportunités sans coordonnées
      end
    end

    resources :stories, only: %i[index edit update destroy] do
      collection do
        post :bulk                # Actions groupées sur les stories
        post :geocode_missing
      end
    end
  end
end
