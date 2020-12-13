class AddDetailsToLineBots < ActiveRecord::Migration[6.0]
  def change
    add_column :line_bots, :message_sender, :string
    add_column :line_bots, :received_message, :string
    add_column :line_bots, :settlement_judge, :string
  end
end
