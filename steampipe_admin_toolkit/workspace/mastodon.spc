# Steampipe Connection Configuration
# Mastodon plugin connection for stranger.social

connection "mastodon" {
  plugin = "mastodon"
  server = "https://stranger.social"
  access_token = env("MASTODON_ADMIN_API_TOKEN")
}
