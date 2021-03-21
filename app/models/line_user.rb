class LineUser < ApplicationRecord
  has_many :tmp_transportation_expenses
  has_many :transportation_expenses
end
