class CreateTmpTransportationExpenses < ActiveRecord::Migration[6.0]
  def change
    create_table :tmp_transportation_expenses do |t|
      t.bigint :fee
      t.timestamps
    end
  end
end
