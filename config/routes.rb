# config/routes.rb
Rails.application.routes.draw do
  # --- SITE PUBLIC ---

  # Page d'accueil : le diorama (ex-/labo/accueil). L'ancienne accueil (hero « Change ta vie, ») est
  # conservée sous /pourquoi-declic.
  root "labo#accueil"
  get "pourquoi-declic", to: "pages#home", as: :pourquoi_declic

  # Opportunités publiques
  resources :opportunities, only: %i[index show new create] do
    collection do
      # Page de remerciement après validation d'une proposition
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

  get "/mentions-legales", to: "pages#legal",           as: :mentions_legales
  get "/confidentialite",  to: "pages#confidentialite", as: :confidentialite
  get "/presse",           to: "pages#presse",          as: :presse
  get "/faq",              to: "pages#faq",             as: :faq
  get "contact", to: "pages#contact"

  # Page de test du pyramide de tuiles diorama (non liée depuis la navigation)
  get "labo/diorama", to: "labo#diorama", as: :labo_diorama
  # Ancienne adresse de la nouvelle accueil : redirection permanente vers la racine (favoris, liens
  # partagés), en gardant la query string (?favoris=1).
  get "labo/accueil", to: redirect(301) { |_params, req| req.query_string.present? ? "/?#{req.query_string}" : "/" }, as: :labo_accueil
  # Refonte des pages Opportunités et Belles Histoires (navbar du labo) : remplacent, sur les pages
  # du labo, les liens vers /opportunities et /stories. Ceux-ci restent en service côté public.
  get "labo/opportunites", to: "labo#opportunites", as: :labo_opportunites
  get "labo/belles-histoires", to: "labo#belles_histoires", as: :labo_belles_histoires
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
      collection do
        post :geocode_missing
      end
    end

    resources :stories do
      member do
        patch :toggle_active # Crée toggle_active_admin_story_path(id)
      end
      collection do
        post :geocode_missing
      end
    end

    # --- VEILLE « BELLES HISTOIRES » ---
    # Outil interne de repérage. Aucune route publique : tout est derrière
    # l'authentification admin (Admin::BaseController).
    namespace :veille do
      root to: "candidates#index"

      resources :candidates, only: %i[index show] do
        member do
          patch :retenir
          patch :ecarter
          patch :a_verifier
          post  :valider # crée le brouillon Opportunity ou Story (inactif)
          post  :rediger # passe B — appel Sonnet, réponse en Turbo Stream
          post  :publier # crée la Story et purge full_text
        end
      end

      resources :sources, except: :show
    end
  end
end
