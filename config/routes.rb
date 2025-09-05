Rails.application.routes.draw do
  # Page d’accueil
  root "pages#home"

  # Opportunités (pages HTML)
  resources :opportunities, only: [:index, :show, :new, :create]
get "/parcours/:category", to: "opportunities#index", as: :parcours

  # API JSON (utilisée par la carte et les marqueurs)
  namespace :api do
    namespace :v1 do
      resources :opportunities, only: %i[index show]
    end
  end
end


