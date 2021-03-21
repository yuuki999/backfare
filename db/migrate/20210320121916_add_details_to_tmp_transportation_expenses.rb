class AddDetailsToTmpTransportationExpenses < ActiveRecord::Migration[6.0]
  def change
    add_column :tmp_transportation_expenses, :availability_count, :integer, null: false, default: 0
  end
end
