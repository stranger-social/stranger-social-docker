#!/bin/sh
set -e

# Ensure home directories exist and are owned by steampipe
adduser --disabled-password --gecos "" --uid 10001 steampipe 2>/dev/null || true
mkdir -p /home/steampipe/.steampipe/plugins /home/steampipe/.steampipe/db /home/steampipe/.steampipe/cache /home/steampipe/.steampipe/logs /home/steampipe/.steampipe/config
chown -R 10001:10001 /home/steampipe/.steampipe

# Generate connection config with environment variables
cat > /home/steampipe/.steampipe/config/default.spc << EOF
connection "mastodon" {
  plugin = "mastodon"
  server = "${MASTODON_SERVER:-https://stranger.social}"
  access_token = "${MASTODON_ACCESS_TOKEN}"
}

connection "rss" {
  plugin = "rss"
}
EOF
chown 10001:10001 /home/steampipe/.steampipe/config/default.spc

# Show versions (as steampipe user)
su -s /bin/sh -c 'steampipe -v || true' steampipe
su -s /bin/sh -c 'powerpipe -v || true' steampipe

# Install plugins (as steampipe user)
echo "Installing Steampipe plugins..."
su -s /bin/sh -c 'steampipe plugin install mastodon rss' steampipe || echo "Plugin installation failed, continuing anyway..."

# Start Steampipe service (as steampipe user)
echo "Starting Steampipe service..."
su -s /bin/sh -c 'steampipe service start --database-listen network --foreground &' steampipe &

# Wait for Steampipe service to be ready
echo "Waiting for Steampipe service..."
sleep 8

# Start Powerpipe server (as steampipe user)
echo "Starting Powerpipe server..."
exec su -s /bin/sh -c 'powerpipe server --mod-location /workspace --listen network --port 8080' steampipe
