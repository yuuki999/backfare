class AddDetailsToLineUser < ActiveRecord::Migration[6.0]
  def change
    add_column :line_users, :display_name, :string
    add_column :line_users, :user_id, :string
    add_column :line_users, :language, :string
    add_column :line_users, :picture_url, :string
    add_column :line_users, :status_message, :string
  end
end
