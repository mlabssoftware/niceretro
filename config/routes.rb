Rails.application.routes.draw do
  root 'teams#index'

  resources :teams, only: [:index, :new, :create, :update, :edit] do
    resources :retrospectives do
      resources :demands do
        get 'update_status', on: :member
      end
      resources :doubts
      resources :positive_topics
      resources :negative_topics
    end
  end

  resources :topics do
    member do
      post :like
      post :dislike
    end
  end
end
