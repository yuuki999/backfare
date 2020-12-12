class LineBotsController < ApplicationController
  protect_from_forgery # CSRF対策
  
  def callback
    # Webhockからリクエストを受信する
    body = request.body.read

    client = Line::Bot::Client.new { |config|
      config.channel_secret = ENV['CHANNEL_SECRET']
      config.channel_token = ENV['CHANNEL_TOKEN']
    }

    # 受信したtypeで処理の切り分け
    # 返信する
    events = client.parse_events_from(body)
    events.each do |event|
      case event
        when Line::Bot::Event::Message
          case event.type
          when Line::Bot::Event::MessageType::Text
            # 返信するメッセージ
            message = {
              type: 'text',
              text: '交通費を受理しました。'
            }
            client.reply_message(event['replyToken'], message)

            # 受信したメッセージをDBに保存する
            line_bot = LineBot.new
            line_bot.received_message = event['message']['text']
            line_bot.save

          when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
            response = client.get_message_content(event.message['id'])
            tf = Tempfile.open("content")
            tf.write(response.body)
          end
      end
    end


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
