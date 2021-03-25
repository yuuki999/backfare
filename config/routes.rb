Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get 'tests', to: 'tests#index'
  post 'line_bots', to: 'line_bots#callback'
  get 'admin', to: 'admins#index'
end
