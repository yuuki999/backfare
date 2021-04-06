class AdminsController < ApplicationController
  before_action :authenticate_admin_user!

  def index
    @test = current_admin_user # formテスト用
    # ユーザーが登録した日から、今日までの日付
    @logined_user = current_admin_user
    logined_user_created_at = @logined_user.created_at.strftime("%Y-%m-%d")
    today = Time.now
    @elapsed_months = []
    calc_date_time = Time.parse(logined_user_created_at)
    while(true)
      if calc_date_time > today
        break
      end
      @elapsed_months << calc_date_time.strftime("%Y-%m")
      calc_date_time = calc_date_time.next_month
    end
  end

  def show
    # ログイン中のユーザーかつ、選択した日付の金額を表示する。
    logined_user = current_admin_user
    fares = TransportationExpense.where(line_users_id: logined_user.id).where('created_at like ?', "%#{params[:id]}%") # paramsがidで渡される。どう考えてもidの名前ではないので適切な命名にする。
    @fare = 0
    fares.each do |f|
      @fare += f.fee.to_i
    end
  end
end


