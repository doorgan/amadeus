import Config

if Config.config_env() == :dev do
  # Works because the dependency is already compiled
  DotenvParser.load_file(".env")
end

config :nostrum,
  # The token of your bot as a string
  token: System.fetch_env!("BOT_TOKEN"),
  # The number of shards you want to run your bot under, or :auto.
  num_shards: :auto

config :amadeus,
  admin_id: System.fetch_env!("ADMIN_ID"),
  command_registration: System.get_env("TEST_GUILD"),
  youtube_api_key: System.fetch_env!("YOUTUBE_API_KEY")
