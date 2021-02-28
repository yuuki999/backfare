class AddDetailsToTmpTransportationExpense < ActiveRecord::Migration[6.0]
  def change
    add_reference :tmp_transportation_expenses, :line_users, foreign_key: true
  end
end
