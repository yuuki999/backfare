Rails.application.routes.draw do
  devise_for :admin_users, controllers: {
    omniauth_callbacks: "omniauth_callbacks"
  }

   # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get 'tests', to: 'tests#index'
  post 'line_bots', to: 'line_bots#callback'
  get 'admin', to: 'admins#index'
  get '/admin/:id', to: 'admins#show'

  # どのパスにも一致しない場合。
  # TODO: 404 not found ページを用意する。
  match '*path', to: redirect('/'), via: :all
end
