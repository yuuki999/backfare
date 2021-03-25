class Config

  def line_bot_access_auth
    client = Line::Bot::Client.new { |config|
      config.channel_secret = ENV['CHANNEL_SECRET']
      config.channel_token = ENV['CHANNEL_TOKEN']
    }
  end
end