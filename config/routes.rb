Rails.application.routes.draw do
  devise_for :users, :controllers => { omniauth_callbacks: 'users/omniauth_callbacks', sessions: 'users/sessions' }, :skip => [:registrations]
  root 'static#index'

  resources :users, :path => "/" do
    collection do
      match 'complete' => 'users#complete', via: [:get, :patch], :as => :complete
      get 'loadrepos' => 'users#loadrepos'
    end
  end

  resources :interests
end
