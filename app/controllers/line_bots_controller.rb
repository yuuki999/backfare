class LineBotsController < ApplicationController
  protect_from_forgery # CSRF対策
  
  def callback
    # Webhockからリクエストを受信する
    body = request.body.read

    # トークン情報
    client = Line::Bot::Client.new { |config|
      config.channel_secret = ENV['CHANNEL_SECRET']
      config.channel_token = ENV['CHANNEL_TOKEN']
    }

    # webhockから送信される情報
    events = client.parse_events_from(body)

    # メッセージ送信者のIDを取得する
    contact = ''
    response = client.get_profile(events[0]['source']['userId'])
    case response
    # 成功
    when Net::HTTPSuccess then
        line_user = LineUser.new
        contact = JSON.parse(response.body)

        # 同じ送信者を保存しない
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
          end
        else
          # 既にline user登録済み
        end
    # 失敗
    else
      return 'NG'
    end

    # メッセージを受け取る
    events.each do |event|
      # 確認テンプレート表示中か判断
      line_bot = LineBot.new
      # ここでユーザー名が分からないと、誰のフラグがYなのか判断できない
      # message_senderの値とsettlement_judgeがYだった場合は交通費を受理する
      if LineBot.find_by(message_sender: contact['userId'], settlement_judge: 'Y')
        # 確認テンプレートでYesなら金額を保存
        if event['message']['text'] == 'Yes'
          message = {
            type: 'text',
            text: '交通費を受理しました。'
          }
          client.reply_message(event['replyToken'], message)

          # 受信した金額をDBに保存する
          line_bot.received_message = event['message']['text']
          line_bot.save

          return 'OK'
        end    
      end
      
      # 金額受取、確認テンプレートを表示する
      if event.type == Line::Bot::Event::MessageType::Text
        # 整数でない場合は、受理せず、エラーメッセージを返信する
        unless /^[0-9]*$/ =~ event['message']['text'].to_s
          message = {
            type: 'text',
            text: '整数を入力してください。'
          }
          client.reply_message(event['replyToken'], message)

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

        # 確認テンプレート表示まで処理したら、保存のフラグを付ける
        ActiveRecord::Base.transaction do
          LineBot.find_by(message_sender: contact['userId']).update(settlement_judge: 'Y')
        end

        return 'OK'
      end
    end

    # デバック
    logger.debug("body: #{body}")
    logger.debug("events: #{events}")
    logger.debug("Line::Bot::Event::Message: #{Line::Bot::Event::Message}")
    logger.debug("Line::Bot::Event::MessageType::Text: #{Line::Bot::Event::MessageType::Text}")
    logger.debug("Line::Bot::Event::MessageType::Image: #{Line::Bot::Event::MessageType::Image}")
    logger.debug("Line::Bot::Event::MessageType::Image: #{Line::Bot::Event::MessageType::Image}")
    logger.debug("ENV['CHANNEL_SECRET']: #{ENV['CHANNEL_SECRET']}")
    logger.debug("ENV['CHANNEL_TOKEN']: #{ENV['CHANNEL_TOKEN']}")

    return 'OK'
  end
end
