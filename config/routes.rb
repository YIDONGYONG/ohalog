Rails.application.routes.draw do
  # ヘルスチェック（ログイン不要・DBに触れない）。Render の Health Check Path とスリープ対策の ping 先に使う
  get "up", to: "rails/health#show", as: :rails_health_check
  root "static_pages#top"
  resources :users, only: %i[new create]
  resources :visions, except: :show do
    # 達成のチェック / 取り消し / 最優先の切り替え
    member do
      patch :achieve
      patch :reopen
      patch :prioritize
    end
  end
  # 「やってみた」の記録(タイマー完了・途中でやめた・ワンタップ完了)。Turbo Stream で画面を更新する
  resources :activity_logs, only: :create
  resources :weekly_reviews, only: [] do
    member do
      post :acknowledge
      post :accept
      post :decline
    end
  end
  resources :routines, only: %i[index create] do
    member do
      post :complete
      post :miss
    end
  end
  get "login", to: "user_sessions#new"
  post "login", to: "user_sessions#create"
  delete "logout", to: "user_sessions#destroy"
end
