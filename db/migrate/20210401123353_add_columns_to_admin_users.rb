class AddColumnsToAdminUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :admin_users, :provider, :string
    add_column :admin_users, :uid, :string
    add_column :admin_users, :username, :string
  end
end
