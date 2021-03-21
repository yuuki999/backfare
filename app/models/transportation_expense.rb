class TransportationExpense < ApplicationRecord
  belongs_to :line_user, optional: true
end
