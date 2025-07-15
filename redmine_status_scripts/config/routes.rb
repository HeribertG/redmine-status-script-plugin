Rails.application.routes.draw do
  resources :status_scripts do
    member do
      patch :toggle
      post :test
    end
    collection do
      get :logs
    end
  end
  
  # API-Routen für externe Integration
  namespace :api do
    namespace :v1 do
      resources :status_scripts, only: [:index, :show] do
        collection do
          get :logs
        end
      end
    end
  end
end