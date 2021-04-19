class CreateHowToUses < ActiveRecord::Migration[6.0]
  def change
    create_table :how_to_uses do |t|

      t.timestamps
    end
  end
end
