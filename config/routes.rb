# config/routes.rb
Rails.application.routes.draw do
  root "pages#home"

  resources :opportunities, only: [:index, :show, :new, :create]
  get "/parcours/:category", to: "opportunities#index", as: :parcours

  # NEW
  resources :stories, only: [:index, :show]

  namespace :api do
    namespace :v1 do
      resources :opportunities, only: %i[index show]
      # NEW (pins « belles histoires » sur la carte)
      resources :stories, only: %i[index]
    end
  end

  # Pages statiques (ressources)
get "/mentions-legales", to: "pages#legal",          as: :mentions_legales
get "/confidentialite",  to: "pages#confidentialite", as: :confidentialite
get "/presse",           to: "pages#presse",         as: :presse
get "/faq",              to: "pages#faq",            as: :faq

end


