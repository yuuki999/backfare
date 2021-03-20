class LineBotsController < ApplicationController
  skip_before_action :verify_authenticity_token # CSRF対策

  ACCESPT_MESSAGE = {
    type: 'text',
    text: '交通費を受理しました。'
  }

  ERROR_MESSAGE = {
    type: 'text',
    text: '整数を入力してください。'
  }
  
  def callback
    # Webhockからリクエストを受信する
    body = request.body.read

    # line botアクセストークン情報
    config = Config.new
    client = config.line_bot_access_auth
    logger.debug("body: #{body}")

    # webhockから送信される情報
    events = get_webhock_events(client, body)
    logger.debug("events: #{events}")

    # メッセージ送信者のIDを取得する
    response = get_line_user_profile(client, events)
    logger.debug("response: #{response}")

    # TODO レスポンスチェックをする。
    contact = JSON.parse(response.body)
    logger.debug("contact: #{contact}")

    # 保存済みの送信者の場合、送信者情報を保存しない
    unless line_user_exist?(contact)
      line_user_registration(contact)
    else
      # 既にline user登録済み
      logger.debug("送信者情報保存済み")
    end

    # TODO: 送信者の仮金額保存DBに金額があれば、YESかNOを入力するように求める
    # 3回間違えると仮金額保存DBから削除する。
    # たぶん、settlement_judgeカラムはいらいない。仮金額保存DBで何とかなると思う。実装が進み問題がないことが確認出来たら削除する。


    event = events[0]
    line_bot = LineBot.new
    if accept_transportation_expenses?(contact)
      # 確認テンプレートでYesなら金額を保存
      if answer_yes?(event)
        reply_to_save_transportation_expenses(client, event)
        save_transportation_expenses(line_bot)
      end
    end
    
    # 金額受取、確認テンプレートを表示する
    if event_type_text?(event)
      logger.debug("確認テンプレート表示処理")
      # 整数でない場合は、受理せず、エラーメッセージを返信する
      unless integer_check?(event)
        reply_when_not_integer(event, client)
      end
      confirmation_template = confirmation_template_message_create(event)
      replay_confirmation_template(event, client, confirmation_template)
      flag_save(contact)

      # 仮のDBに金額を保存する。
      tmp_te = TmpTransportationExpense.new

      if line_user_exist?(contact)
        line_user = LineUser.find_by(user_id: contact['userId'])
        logger.debug("line_user_id: #{line_user.id}")
        logger.debug("tmp_te: #{tmp_te.line_users_id }")

        save_transportation_expenses_in_tmp_db(line_user)
      end
    end
  end

  private
  # webhockのレスポンスを取得
  def get_webhock_events(client, body)
    events = client.parse_events_from(body)
  end

  # ユーザーのプロファイル情報を抽出
  def get_line_user_profile(client, events)
    response = client.get_profile(events[0]['source']['userId'])
  end

  # ユーザーがDBに存在するかチェック
  def line_user_exist?(contact)
    LineUser.exists?(user_id: contact['userId']) ? true : false
  end

  # ユーザーの登録
  # TODO
  # モデルに切り出す。self.exists?のようには書けないので、LineUserモデル内でLineUser.exists?のように書くしかないか。
  def line_user_registration(contact)
    line_user = LineUser.new

    logger.debug("送信者情報の保存処理開始")
    ActiveRecord::Base.transaction do
      line_user.display_name = contact['displayName']
      line_user.user_id = contact['userId']
      line_user.language = contact['language']
      line_user.picture_url = contact['pictureUrl']
      line_user.status_message = contact['statusMessage']
      line_user.save

      line_bot = LineBot.new
      line_bot.message_sender = contact['userId']
      line_bot.save
      logger.debug("送信者情報の保存処理成功")
    end
  end

  # message_senderの値とsettlement_judgeがYだった場合は交通費を受理する
  def accept_transportation_expenses?(contact)
    LineBot.find_by(message_sender: contact['userId'], settlement_judge: 'Y') ? true : false
  end

  # 返答がYESか判断
  def answer_yes?(event)
    event['message']['text'] == 'Yes' ? true : false
  end

  # 交通費保存完了メッセージの送信
  def reply_to_save_transportation_expenses(client, event)
    client.reply_message(event['replyToken'], ACCESPT_MESSAGE)
    logger.debug("受理メッセージ送信完了")
  end

  # 交通費をDBに保存
  def save_transportation_expenses(line_bot)
    logger.debug("交通費保存処理開始")
    line_bot.received_message = event['message']['text'] # DBにYESかNOかを保存するようにしているが、何に使うのか不明、消すか？
    line_bot.save
    logger.debug("交通費保存成功")
  end

  # イベントがのタイプがtextかどうか
  def event_type_text?(event)
    event.type == Line::Bot::Event::MessageType::Text ? true : false
  end

  # メッセージの整数チェック
  def integer_check?(event)
    /^[0-9]*$/ =~ event['message']['text'].to_s ? true : false
  end

  # エラーメッセージ
  def reply_when_not_integer(event, client)
    client.reply_message(event['replyToken'], ERROR_MESSAGE)
    logger.debug("メッセージが整数ではなかった。")
  end

  # 確認テンプレート作成
  def confirmation_template_message_create(event)
    confirmation_template = {
      type: "template",
      altText: "this is a confirm template",
      template: {
          type: "confirm",
          text: "交通費: ￥#{event['message']['text']}\n受理しますか？",
          actions: [
            {
              type: "message",
              label: "Yes",
              text: "Yes"
            },
            {
              type: "message",
              label: "No",
              text: "No"
            }
          ]
      }
    }
  end

  # 確認テンプレート送信
  def replay_confirmation_template(event, client, confirmation_template)
    client.reply_message(event['replyToken'], confirmation_template)
    logger.debug("event['replyToken'] #{event['replyToken']}")
    logger.debug("確認テンプレート表示完了")
  end

  
  def flag_save(contact)
    ActiveRecord::Base.transaction do
      LineBot.find_by(message_sender: contact['userId']).update(settlement_judge: 'Y')
    end
  end

  # 交通費を一時DBに保存
  def save_transportation_expenses_in_tmp_db(line_user)
    # 外部キーへの保存がうまくいかないので直クエリを書いた。
    res = ActiveRecord::Base.connection.execute("INSERT INTO `tmp_transportation_expenses` (`fee`, `line_users_id`, `created_at`, `updated_at`) VALUES (1, '#{line_user.id}', '2021-02-24 08:54:02.595447', '2021-02-24 08:54:02.595447')")   
  end
end
