# config/routes.rb
Rails.application.routes.draw do
  # --- SITE PUBLIC ---

  # Page d’accueil
  root "pages#home"

  # Opportunités publiques
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

  # Belles histoires publiques
  resources :stories, only: %i[index show new create] do
    collection do
      get :merci
    end
  end

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

  # Lettre Opener en dev
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # --- ADMIN ---

  namespace :admin do
    root to: "opportunities#index"

    resources :opportunities, except: [:show] do
      member do
        patch :toggle_active
      end
    end

    resources :stories, except: [:show]
  end
end
