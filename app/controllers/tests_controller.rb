class TestsController < ApplicationController
  def index
    # 返信したいメッセージ
    message = {
      type: 'text',
      text: 'hello'
    }
    # 
    client = Line::Bot::Client.new { |config|
        config.channel_secret = "<channel secret>"
        config.channel_token = "<channel access token>"
    }
    response = client.reply_message("<replyToken>", message)
    p response    
  end
end
