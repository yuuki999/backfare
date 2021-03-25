class LineBotsController < ApplicationController
  skip_before_action :verify_authenticity_token # CSRF対策

  ACCESPT_MESSAGE = {
    type: 'text',
    text: '交通費を受理しました。'
  }

  ERROR_MESSAGE = {
    type: 'text',
    text: '交通費を整数で入力してください。'
  }

  SAVE_CONFIRMATION_MESSAGE = {
    type: 'text',
    text: "以前入力した交通費の情報が残っています。\n保存ならYes、取り消しならNoを入力してください。\nこの処理は3回繰り返すと、以前入力した交通費が取り消されます。"
  }

  DELETE_MESSAGE = {
    type: 'text',
    text: "3回間違えました。以前入力した交通費を削除しました。"
  }

  NO_MESSAGE = {
    type: 'text',
    text: "以前入力した交通費を取り消しました。"
  }

  # TODO: line_botsテーブルいる？
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

    event = events[0]
    # 送信者の仮金額保存テーブルに金額があれば、YESかNOを入力するように求める
    # たぶん、settlement_judgeカラムはいらいない。仮金額保存DBで何とかなると思う。実装が進み問題がないことが確認出来たら削除する。
    tmp_expense = TmpTransportationExpense
    line_user = get_line_user_info(contact)
    tmp_expense_row = tmp_transportation_fee_exists?(tmp_expense, line_user)
    unless tmp_expense_row.nil?
      logger.debug("仮DBはあるようだ")

      line_bot = LineBot.new
      # 確認テンプレートでYesなら金額を保存。
      # 仮交通費を削除する。
      if answer_yes?(event)
        reply_to_save_transportation_expenses(client, event)
        save_transportation_expenses(line_bot, event, line_user.id)
        tmp_transportation_fee_delete(tmp_expense_row)
        return
      end

      # 確認テンプレートでNoなら仮金額テーブルから削除する。
      if answer_no?(event)
        tmp_transportation_fee_delete(tmp_expense_row)
        send_tmp_fee_delete_message(client, event)
        return
      end

      # 3回間違えると仮金額保存DBから削除する。
      if tmp_expense_row.availability_count > 2
        tmp_transportation_fee_delete(tmp_expense_row)
        send_delete_message(client, event)
        return
      end

      # ユーザーに仮金額は保存済みなので入力しなおさせる。
      increase_the_availability_count(tmp_expense_row)
      # YESかNOを入力してくれとリプライする。
      yes_or_no_answer(client, event)
      return
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

        save_transportation_expenses_in_tmp_db(line_user, event)
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
  # TODO: Yesは大文字、小文字の区別はしない、寛容に許可したい。
  def answer_yes?(event)
    event['message']['text'] == 'Yes' ? true : false
  end

  def answer_no?(event)
    event['message']['text'] == 'No' ? true : false
  end

  # 交通費保存完了メッセージの送信
  def reply_to_save_transportation_expenses(client, event)
    client.reply_message(event['replyToken'], ACCESPT_MESSAGE)
    logger.debug("受理メッセージ送信完了")
  end

  # 交通費をDBに保存
  # TODO: 仮金額から金額を移植するようにする。
  def save_transportation_expenses(line_bot, event, line_user_id)
    logger.debug("交通費保存処理開始")
    tmp_expense = TmpTransportationExpense
    tmp_fee = tmp_expense.find_by(line_users_id: line_user_id)
    transportation_expense = TransportationExpense.new
    transportation_expense.line_users_id = line_user_id
    transportation_expense.fee = tmp_fee.fee
    transportation_expense.save
    tmp_fee.delete

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

  # 削除メッセージを送信。
  def send_delete_message(client, event)
    client.reply_message(event['replyToken'], DELETE_MESSAGE)
  end

  # 使わなくなる可能性あり。
  def flag_save(contact)
    ActiveRecord::Base.transaction do
      LineBot.find_by(message_sender: contact['userId']).update(settlement_judge: 'Y')
    end
  end

  # 交通費を一時DBに保存
  # TODO: 一時的に交通費を保存するテーブルを作成したが、line_userテーブルのカラムで仮交通費を保存する方法でもいいかもしれない。
  # どちらの方がいいのだろうか？
  def save_transportation_expenses_in_tmp_db(line_user, event)
    # 外部キーへの保存がうまくいかないので直クエリを書いた。
    fee = event['message']['text']
    res = ActiveRecord::Base.connection.execute("INSERT INTO `tmp_transportation_expenses` (`fee`, `line_users_id`, `created_at`, `updated_at`) VALUES (#{fee}, '#{line_user.id}', '2021-02-24 08:54:02.595447', '2021-02-24 08:54:02.595447')")   
  end

  # 登録済みのLineUserの情報を取得。
  def get_line_user_info(contact)
    LineUser.find_by(user_id: contact['userId'])
  end

  # 仮交通費が存在するか。
  def tmp_transportation_fee_exists?(tmp_expense, line_user)
    tmp_expense.find_by(line_users_id: line_user.id) 
  end

  # 仮交通費を削除。
  def tmp_transportation_fee_delete(tmp_expense_row)
    logger.debug("仮金額を削除開始")
    tmp_expense_row.delete
    logger.debug("仮金額を削完了")
  end

  def increase_the_availability_count(tmp_expense_row)
    tmp_expense_row.update(availability_count: tmp_expense_row.availability_count += 1)
  end

  def yes_or_no_answer(client, event)
    client.reply_message(event['replyToken'], SAVE_CONFIRMATION_MESSAGE)
  end

  def send_tmp_fee_delete_message(client, event)
    client.reply_message(event['replyToken'], NO_MESSAGE)
  end
end
