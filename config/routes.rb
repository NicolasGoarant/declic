# config/routes.rb
Rails.application.routes.draw do
  root "pages#home"

  resources :opportunities, only: [:index, :show, :new, :create]
  get "/parcours/:category", to: "opportunities#index", as: :parcours

  get "philosophie", to: "pages#philosophie", as: :philosophie

  resources :stories, only: %i[index show]

  namespace :api do
    namespace :v1 do
      resources :opportunities, only: %i[index show]
      resources :stories, only: %i[index]
    end
  end

  get "/mentions-legales", to: "pages#legal",           as: :mentions_legales
  get "/confidentialite",  to: "pages#confidentialite", as: :confidentialite
  get "/presse",           to: "pages#presse",          as: :presse
  get "/faq",              to: "pages#faq",             as: :faq

  # --- ADMIN ---
  namespace :admin do
    root to: "opportunities#index"
    resources :opportunities, only: [:index, :edit, :update, :destroy] do
      collection do
        post :bulk      # actions groupées (activate/deactivate/destroy)
        post :geocode_missing
      end
    end
  end

  # config/routes.rb (ajouts)
  namespace :admin do
    resources :stories, only: %i[index edit update destroy] do
      collection do
        post :bulk         # actions groupées (supprimer, activer… si tu ajoutes un booléen plus tard)
        post :geocode_missing
      end
    end
  end

end
