class AddDetailsToTransportationExpense < ActiveRecord::Migration[6.0]
  def change
    add_reference :transportation_expenses, :line_users, foreign_key: true
  end
end
