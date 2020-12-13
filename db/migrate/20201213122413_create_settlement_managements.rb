class CreateSettlementManagements < ActiveRecord::Migration[6.0]
  def change
    create_table :settlement_managements do |t|

      t.timestamps
    end
  end
end
