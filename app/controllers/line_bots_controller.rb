class LineBotsController < ApplicationController
  skip_before_action :verify_authenticity_token # CSRF対策
  
  def callback
    # Webhockからリクエストを受信する
    body = request.body.read

    logger.debug("ENV['CHANNEL_SECRET']: #{ENV['CHANNEL_SECRET']}")
    logger.debug("ENV['CHANNEL_TOKEN']: #{ENV['CHANNEL_TOKEN']}")

    # line botアクセストークン情報
    config = Config.new
    client = config.line_bot_access_auth

    logger.debug("body: #{body}")

    # webhockから送信される情報
    events = client.parse_events_from(body)

    logger.debug("events: #{events}")

    # メッセージ送信者のIDを取得する
    # TODO ビジネスロジックなので切り分けるべきでは？
    contact = ''
    response = client.get_profile(events[0]['source']['userId'])
    logger.debug("response: #{response}")

    # TODO レスポンスチェックをする。
    line_user = LineUser.new
    # JSONに変換するコードはモデルに書くべきか？
    # コントローラーに書くべき、理由は、仮にモデルにJSON変換メソッドを定義しなくても、1行で変換コードは読み出せ完結するので、冗長になる。
    # 2行以上であればメソッドに切り出す価値はありそうだが、そうではないので切り出すべきではないだろう。
    contact = JSON.parse(response.body)
    logger.debug("contact: #{contact}")

    # 同じ送信者を保存しない
    # TODO
    # ここの判定処理はビジネスロジックっぽいのでモデルに書き出すべき？
    # ではモデルでLineUser.exists?みたいな処理はどう書けるのか？
    # self.exists?のようには書けないので、LineUserモデル内でLineUser.exists?のように書くしかないか。
    unless LineUser.exists?(user_id: contact['userId'])
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

        logger.debug("送信者情報の保存")
      end
    else
      # 既にline user登録済み
      logger.debug("送信者情報保存済み")
    end

    # メッセージを受け取る
    # TODO
    # 
    events.each do |event|
      # 確認テンプレート表示中か判断
      # TODO: モデルに切り分け
      line_bot = LineBot.new
      # ここでユーザー名が分からないと、誰のフラグがYなのか判断できない
      # message_senderの値とsettlement_judgeがYだった場合は交通費を受理する
      if LineBot.find_by(message_sender: contact['userId'], settlement_judge: 'Y')
        logger.debug("交通費受理処理開始")
        # 確認テンプレートでYesなら金額を保存
        if event['message']['text'] == 'Yes'
          message = {
            type: 'text',
            text: '交通費を受理しました。'
          }
          client.reply_message(event['replyToken'], message)

          logger.debug("受理メッセージ送信完了")

          # 受信した金額をDBに保存する
          line_bot.received_message = event['message']['text']
          line_bot.save

          logger.debug("金額保存完了")

          return 'OK'
        end    
      end
      
      # 金額受取、確認テンプレートを表示する
      if event.type == Line::Bot::Event::MessageType::Text
        logger.debug("確認テンプレート表示処理")
        # 整数でない場合は、受理せず、エラーメッセージを返信する
        unless /^[0-9]*$/ =~ event['message']['text'].to_s
          message = {
            type: 'text',
            text: '整数を入力してください。'
          }
          client.reply_message(event['replyToken'], message)

          logger.debug("金額以外が入力された")

          return 'NG'
        end

        # 確認テンプレート表示
        message = {
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
        client.reply_message(event['replyToken'], message)

        logger.debug("event['replyToken'] #{event['replyToken']}")
        logger.debug("確認テンプレート表示完了")

        # 確認テンプレート表示まで処理したら、保存のフラグを付ける
        ActiveRecord::Base.transaction do
          LineBot.find_by(message_sender: contact['userId']).update(settlement_judge: 'Y')
        end

        # 仮のDBに金額を保存する。
        tmp_te = TmpTransportationExpense.new

        # tmp_te.fee = event['message']['text'].to_s
        line_user = LineUser.find_by(user_id: contact['userId'])
        logger.debug("line_user_id: #{line_user.id}")
        logger.debug("tmp_te: #{tmp_te.line_users_id }")
        
        # 外部キーへの保存がうまくいかないので直クエリを書いた。
        res = ActiveRecord::Base.connection.execute("INSERT INTO `tmp_transportation_expenses` (`fee`, `line_users_id`, `created_at`, `updated_at`) VALUES (1, '#{line_user.id}', '2021-02-24 08:54:02.595447', '2021-02-24 08:54:02.595447')")
        
        return 'OK'
      end
    end


    return 'OK'
  end
end
