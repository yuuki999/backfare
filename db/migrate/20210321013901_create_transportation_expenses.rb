class CreateTransportationExpenses < ActiveRecord::Migration[6.0]
  def change
    create_table :transportation_expenses do |t|
      t.bigint :fee
      t.timestamps
    end
  end
end
