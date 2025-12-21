connection "mastodon" {
  plugin = "mastodon"
  
  # Mastodon instance server URL
  server = "https://stranger.social"
  
  # Access token for authentication
  # Get your token from: https://stranger.social/settings/applications
  access_token = env("MASTODON_ACCESS_TOKEN")
}

connection "rss" {
  plugin = "rss"
}
