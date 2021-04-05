class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :trackable,
         :recoverable, :rememberable, :validatable, :lockable, :registerable,
         :omniauthable, omniauth_providers: %i[line]

  def self.from_omniauth(auth)
    # テーブルにデータがあればselect、テーブルにデータがなければ新規作成をやっている。
    # 1. ユーザーが存在するか確認する。(トークンで判定する。)select...
    # 2. ユーザーが存在した場合は、selectした結果をreturnする。
    # 3. ユーザーが1で存在しない場合は、1の情報で新たにユーザーを作成する。
    # 4. 3の場合は、3をDBに保存し、returnする。

    self_user = find_by(provider: auth.provider, uid: auth.uid)
    logger.debug "auth #{auth}"
    logger.debug "passwd #{Devise.friendly_token[0, 20]}"
    logger.debug "self_user #{self_user}"
    if self_user
      return self_user
    else
      self_user = new
      logger.debug "self_user #{self_user}"
      # self_user.email = auth.info.email # emailがレスポンスにない。拡張する必要がある。https://qiita.com/free_man/items/cc731afc27a06e4f493a
      # 後でemailは登録で切るようにしてあげるか。
      self_user.email = "line_user_#{Devise.friendly_token[0, 20]}@example.com"
      self_user.password = Devise.friendly_token[0, 20]
      self_user.sign_in_count = 0
      self_user.failed_attempts = 0
      self_user.provider = auth.provider
      self_user.uid = auth.uid
      self_user.save!

      return self_user
    end
  end
end
