# config/routes.rb
Rails.application.routes.draw do
  root "pages#home"
  resources :opportunities, only: [:show, :index]

  namespace :api do
    namespace :v1 do
      resources :opportunities, only: [:index, :show]
    end
  end
end

