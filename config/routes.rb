Rails.application.routes.draw do
  devise_for :admin_users, controllers: {
    omniauth_callbacks: "omniauth_callbacks"
  }

  get 'tests', to: 'tests#index'
  post 'line_bots', to: 'line_bots#callback'
  get 'admin', to: 'admins#index'
  get '/admin/:id', to: 'admins#show'
  get 'how_to_uses', to: 'how_to_uses#index'

  # どのパスにも一致しない場合。
  # TODO: 404 not found ページを用意する。
  match '*path', to: redirect('/'), via: :all
end
