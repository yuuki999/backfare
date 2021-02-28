class TmpTransportationExpense < ApplicationRecord
  belongs_to :line_user, optional: true
end
